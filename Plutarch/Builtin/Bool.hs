{-# LANGUAGE UndecidableInstances #-}

module Plutarch.Builtin.Bool (
  -- * Type
  PBool (..),

  -- * Builtin
  pbuiltinIfThenElse,

  -- * Functions
  pif',
  pif,
  pnot,
  (#&&),
  (#||),
  por,
  pand,
  pand',
  por',
  pcond,
  potherwise,
) where

import Data.Kind (Type)
import Data.List.NonEmpty (NonEmpty ((:|)))
import Plutarch.Internal.Lift (
  DeriveBuiltinPLiftable,
  PLiftable,
  PLifted (PLifted),
  pconstant,
 )
import Plutarch.Internal.PLam (plam)
import Plutarch.Internal.PlutusType (
  PlutusType (PInner, pcon', pmatch'),
  pcon,
  pmatch,
 )
import Plutarch.Internal.Term (
  PDelayed,
  S,
  Term,
  pdelay,
  pforce,
  phoistAcyclic,
  punsafeBuiltin,
  (#),
  (:-->),
 )
import PlutusCore qualified as PLC

{- | Builtin Plutus boolean.

@since WIP
-}
data PBool (s :: S) = PTrue | PFalse
  deriving stock
    ( -- | @since WIP
      Show
    )

-- | @since WIP
deriving via
  (DeriveBuiltinPLiftable PBool Bool)
  instance
    PLiftable PBool

-- | @since WIP
instance PlutusType PBool where
  type PInner PBool = PBool
  {-# INLINEABLE pcon' #-}
  pcon' =
    pconstant . \case
      PTrue -> True
      PFalse -> False
  {-# INLINEABLE pmatch' #-}
  pmatch' b f = pforce $ pif' # b # pdelay (f PTrue) # pdelay (f PFalse)

-- | @since WIP
pbuiltinIfThenElse ::
  forall (a :: S -> Type) (s :: S).
  Term s (PBool :--> a :--> a :--> PDelayed a)
pbuiltinIfThenElse = punsafeBuiltin PLC.IfThenElse

{- | Strict if-then-else. Emits slightly less code than the lazy version.

@since WIP
-}
pif' ::
  forall (a :: S -> Type) (s :: S).
  Term s (PBool :--> a :--> a :--> a)
pif' = phoistAcyclic $ pforce $ punsafeBuiltin PLC.IfThenElse

{- | Lazy if-then-else.

@since WIP
-}
pif ::
  forall (a :: S -> Type) (s :: S).
  Term s PBool ->
  Term s a ->
  Term s a ->
  Term s a
pif cond ifT ifF = pmatch cond $ \case
  PTrue -> ifT
  PFalse -> ifF

{- | Boolean negation.

@since WIP
-}
pnot ::
  forall (s :: S).
  Term s (PBool :--> PBool)
pnot = phoistAcyclic $ plam $ \x ->
  pif' # x # pcon PFalse # pcon PTrue

{- | Lazy AND for terms.

@since WIP
-}
(#&&) :: forall (s :: S). Term s PBool -> Term s PBool -> Term s PBool
x #&& y = pforce $ pand # x # pdelay y

infixr 3 #&&

{- | Lazy OR for terms.

@since WIP
-}
(#||) :: forall (s :: S). Term s PBool -> Term s PBool -> Term s PBool
x #|| y = pforce $ por # x # pdelay y

infixr 2 #||

{- | Hoisted lazy AND at the Plutarch level.

@since WIP
-}
pand :: forall (s :: S). Term s (PBool :--> PDelayed PBool :--> PDelayed PBool)
pand = phoistAcyclic $ plam $ \x y -> pif' # x # y # phoistAcyclic (pdelay $ pcon PFalse)

{- | As 'pand', but strict.

@since WIP
-}
pand' :: forall (s :: S). Term s (PBool :--> PBool :--> PBool)
pand' = phoistAcyclic $ plam $ \x y -> pif' # x # y # pcon PFalse

{- | Hoisted lazy OR at the Plutarch level.

@since WIP
-}
por :: forall (s :: S). Term s (PBool :--> PDelayed PBool :--> PDelayed PBool)
por = phoistAcyclic $ plam $ \x -> pif' # x # phoistAcyclic (pdelay $ pcon PTrue)

{- | As 'por', but strict.

@since WIP
-}
por' :: Term s (PBool :--> PBool :--> PBool)
por' = phoistAcyclic $ plam $ \x -> pif' # x # pcon PTrue

{- | Multi-way @if@ equivalent for Plutarch. Equivalent to a sequential nesting
of 'pif' from left to right.

= Note

The last entry will be treated as unconditional (effectively, a catch-all
@else@). Thus, what @PBool@ term goes on the end is not relevant.

@since WIP
-}
pcond ::
  forall (a :: S -> Type) (s :: S).
  NonEmpty (Term s PBool, Term s a) ->
  Term s a
pcond = \case
  (_, t) :| [] -> t
  condPair :| condPairs -> go condPair condPairs
    where
      go :: (Term s PBool, Term s a) -> [(Term s PBool, Term s a)] -> Term s a
      go (cond, ifT) = \case
        [] -> ifT
        condPair : condPairs -> pif cond ifT . go condPair $ condPairs

{- | Shorthand for @pcon PTrue@, provided for clarity when using 'pcond'.

@since WIP
-}
potherwise :: forall (s :: S). Term s PBool
potherwise = pcon PTrue
