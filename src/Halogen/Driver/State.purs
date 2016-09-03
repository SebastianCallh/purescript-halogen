module Halogen.Driver.State
  ( DriverState(..)
  , DriverStateRec
  , DriverStateX
  , unDriverStateX
  , initDriverState
  ) where

import Prelude

import Control.Monad.Aff (Aff)
import Control.Monad.Aff.AVar (AVar, putVar, makeVar)
import Control.Monad.Eff.Class (liftEff)

import Data.Map as M

import DOM.HTML.Types (HTMLElement)

import Halogen.Component (Component')
import Halogen.Data.OrdBox (OrdBox)
import Halogen.Effects (HalogenEffects)
import Halogen.Internal.VirtualDOM as V

import Unsafe.Coerce (unsafeCoerce)

-- | The type used to track a driver's persistent state.
newtype DriverState s f g eff p o = DriverState (DriverStateRec s f g eff p o)

type DriverStateRec s f g eff p o =
  { node :: HTMLElement
  , vtree :: V.VTree
  , component :: Component' s f g p o (Aff (HalogenEffects eff))
  , state :: s
  , children :: M.Map (OrdBox p) (AVar (DriverStateX g eff))
  , mkOrdBox :: p -> OrdBox p
  , selfRef :: AVar (DriverState s f g eff p o)
  , handler :: o -> Aff (HalogenEffects eff) Unit
  , keyId :: Int
  , fresh :: AVar Int
  }

-- | A version of `DriverState` with the aspects relating to child components
-- | existentially hidden.
data DriverStateX (f :: * -> *) (eff :: # !)

mkDriverStateXVar
  :: forall s f g eff p o
   . AVar (DriverState s f g eff p o)
  -> AVar (DriverStateX f eff)
mkDriverStateXVar = unsafeCoerce

unDriverStateX
  :: forall f eff r o
   . (forall s g p. DriverStateRec s f g eff p o -> r)
  -> DriverStateX f eff
  -> r
unDriverStateX = unsafeCoerce

initDriverState
  :: forall s f g eff p o
   . Component' s f g p o (Aff (HalogenEffects eff))
  -> (o -> Aff (HalogenEffects eff) Unit)
  -> Int
  -> AVar Int
  -> Aff (HalogenEffects eff) (AVar (DriverStateX f eff))
initDriverState component handler keyId fresh = do
  let vtree = V.vtext ""
  node <- liftEff (V.createElement vtree)
  selfRef <- makeVar
  let
    ds =
      { node
      , vtree
      , component
      , state: component.initialState
      , children: M.empty
      , mkOrdBox: component.mkOrdBox
      , selfRef
      , keyId
      , fresh
      , handler
      }
  putVar selfRef (DriverState ds)
  pure $ mkDriverStateXVar selfRef
