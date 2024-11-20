{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Plutarch.Either (
  -- * Types
  PEither (PLeft, PRight),
  PEitherData (PDLeft, PDRight),

  -- * Functions

  -- ** PEitherData

  -- *** Construction
  pdleft,
  pdright,

  -- *** Elimination
  peitherData,
  pdisLeft,
  pdisRight,
  pdfromLeft,
  pdfromRight,
) where

import Data.Kind (Type)
import GHC.Generics (Generic)
import Plutarch (
  DPTStrat,
  DerivePlutusType,
  PType,
  PlutusTypeScott,
  S,
  Term,
  pcon,
  perror,
  phoistAcyclic,
  plam,
  plet,
  pmatch,
  pto,
  (#),
  (#$),
  (:-->),
 )
import Plutarch.Bool (
  PBool (PFalse, PTrue),
  PEq,
  POrd,
  PPartialOrd ((#<), (#<=)),
  pif,
  (#==),
 )
import Plutarch.Builtin (
  PAsData,
  PData,
  PIsData (pdataImpl, pfromDataImpl),
  pasConstr,
  pconstrBuiltin,
  pdata,
  pforgetData,
  pfromData,
  pfstBuiltin,
  psndBuiltin,
 )
import Plutarch.Internal.Lift (
  DeriveDataPLiftable,
  PLiftable (
    AsHaskell,
    PlutusRepr,
    fromPlutarch,
    toPlutarch
  ),
  PLifted (PLifted),
  PLiftedClosed,
  getPLifted,
  mkPLifted,
  pconstant,
 )
import Plutarch.Internal.PlutusType (PlutusType (PInner, pcon', pmatch'))
import Plutarch.List (pcons, phead, pnil)
import Plutarch.Show (PShow)
import Plutarch.Trace (ptraceInfoError)
import Plutarch.TryFrom (PTryFrom)
import Plutarch.Unsafe (punsafeCoerce)
import PlutusLedgerApi.V3 qualified as Plutus

-- | Scott-encoded 'Either'.
data PEither (a :: PType) (b :: PType) (s :: S)
  = PLeft (Term s a)
  | PRight (Term s b)
  deriving stock (Generic)
  deriving anyclass (PlutusType, PEq, PShow)

instance DerivePlutusType (PEither a b) where
  type DPTStrat _ = PlutusTypeScott

-- | @since WIP
instance (PLiftable a, PLiftable b) => PLiftable (PEither a b) where
  type AsHaskell (PEither a b) = Either (AsHaskell a) (AsHaskell b)
  type PlutusRepr (PEither a b) = PLiftedClosed (PEither a b)

  {-# INLINEABLE toPlutarch #-}
  toPlutarch (Left a) = mkPLifted $ plam (pcon . PLeft) # pconstant @a a
  toPlutarch (Right b) = mkPLifted $ plam (pcon . PRight) # pconstant @b b

  {-# INLINEABLE fromPlutarch #-}
  fromPlutarch t = do
    isLeft <-
      fromPlutarch $
        mkPLifted $
          plam (\e -> pmatch e $ \case PLeft _ -> pconstant @PBool True; PRight _ -> pconstant @PBool False)
            # getPLifted t
    if isLeft
      then
        fmap Left $
          fromPlutarch $
            mkPLifted $
              plam (\e -> pmatch e $ \case PLeft a -> a; PRight _ -> perror) # getPLifted t
      else
        fmap Right $
          fromPlutarch $
            mkPLifted $
              plam (\e -> pmatch e $ \case PLeft _ -> perror; PRight b -> b) # getPLifted t

{- | @Data@-encoded 'Either'.

@since WIP
-}
data PEitherData (a :: S -> Type) (b :: S -> Type) (s :: S)
  = PDLeft (Term s (PAsData a))
  | PDRight (Term s (PAsData b))
  deriving stock
    ( -- | @since WIP
      Generic
    )
  deriving anyclass
    ( -- | @since WIP
      PEq
    , -- | @since WIP
      PShow
    , -- | @since WIP
      POrd
    )

-- | @since WIP
instance
  (PPartialOrd a, PPartialOrd b, PIsData a, PIsData b) =>
  PPartialOrd (PEitherData a b)
  where
  {-# INLINEABLE (#<=) #-}
  t1 #<= t2 = pmatch t1 $ \case
    PDLeft t1' -> pmatch t2 $ \case
      PDLeft t2' -> pfromData t1' #<= pfromData t2'
      PDRight _ -> pcon PTrue
    PDRight t1' -> pmatch t2 $ \case
      PDLeft _ -> pcon PFalse
      PDRight t2' -> pfromData t1' #<= pfromData t2'
  {-# INLINEABLE (#<) #-}
  t1 #< t2 = pmatch t1 $ \case
    PDLeft t1' -> pmatch t2 $ \case
      PDLeft t2' -> pfromData t1' #< pfromData t2'
      PDRight _ -> pcon PTrue
    PDRight t1' -> pmatch t2 $ \case
      PDLeft _ -> pcon PFalse
      PDRight t2' -> pfromData t1' #< pfromData t2'

-- | @since WIP
instance PlutusType (PEitherData a b) where
  type PInner (PEitherData a b) = PData
  {-# INLINEABLE pcon' #-}
  pcon' = \case
    PDLeft t ->
      pforgetData $ pconstrBuiltin # 0 #$ pcons # pforgetData t # pnil
    PDRight t ->
      pforgetData $ pconstrBuiltin # 1 #$ pcons # pforgetData t # pnil
  {-# INLINEABLE pmatch' #-}
  pmatch' t f = plet (pasConstr # t) $ \asConstr ->
    plet (phead #$ psndBuiltin # asConstr) $ \arg ->
      pif
        ((pfstBuiltin # asConstr) #== 0)
        (f . PDLeft . punsafeCoerce $ arg)
        (f . PDRight . punsafeCoerce $ arg)

-- | @since WIP
deriving via
  DeriveDataPLiftable (PEitherData a b) (Either (AsHaskell a) (AsHaskell b))
  instance
    ( Plutus.ToData (AsHaskell a)
    , Plutus.FromData (AsHaskell a)
    , Plutus.ToData (AsHaskell b)
    , Plutus.FromData (AsHaskell b)
    ) =>
    PLiftable (PEitherData a b)

-- | @since WIP
instance PIsData (PEitherData a b) where
  {-# INLINEABLE pdataImpl #-}
  pdataImpl = pto
  {-# INLINEABLE pfromDataImpl #-}
  pfromDataImpl = punsafeCoerce

-- | @since WIP
instance (PTryFrom PData a, PTryFrom PData b) => PTryFrom PData (PEitherData a b)

-- | @since WIP
instance (PTryFrom PData a, PTryFrom PData b) => PTryFrom PData (PAsData (PEitherData a b))

{- | Make a @Data@-encoded @Left@.

@since WIP
-}
pdleft ::
  forall (a :: S -> Type) (b :: S -> Type) (s :: S).
  PIsData a =>
  Term s (a :--> PEitherData a b)
pdleft = phoistAcyclic $ plam $ \x ->
  pcon . PDLeft . pdata $ x

{- | Make a @Data@-encoded @Right@.

@since WIP
-}
pdright ::
  forall (a :: S -> Type) (b :: S -> Type) (s :: S).
  PIsData b =>
  Term s (b :--> PEitherData a b)
pdright = phoistAcyclic $ plam $ \x ->
  pcon . PDRight . pdata $ x

{- | Eliminator for 'PEitherData'.

@since WIP
-}
peitherData ::
  forall (a :: S -> Type) (b :: S -> Type) (r :: S -> Type) (s :: S).
  (PIsData a, PIsData b) =>
  Term s ((a :--> r) :--> (b :--> r) :--> PEitherData a b :--> r)
peitherData = phoistAcyclic $ plam $ \whenLeft whenRight t ->
  pmatch t $ \case
    PDLeft x -> whenLeft # pfromData x
    PDRight x -> whenRight # pfromData x

{- | Verifies if a 'PEitherData' is a 'PDLeft'. Less code than using
'peitherData', as it doesn't need to inspect the contents.

@since WIP
-}
pdisLeft ::
  forall (a :: S -> Type) (b :: S -> Type) (s :: S).
  Term s (PEitherData a b :--> PBool)
pdisLeft = phoistAcyclic $ plam $ \t ->
  pmatch t $ \case
    PDLeft _ -> pcon PTrue
    PDRight _ -> pcon PFalse

{- | As 'pdisLeft', except verifies whether we have a 'PDRight'.

@since WIP
-}
pdisRight ::
  forall (a :: S -> Type) (b :: S -> Type) (s :: S).
  Term s (PEitherData a b :--> PBool)
pdisRight = phoistAcyclic $ plam $ \t ->
  pmatch t $ \case
    PDRight _ -> pcon PTrue
    PDLeft _ -> pcon PFalse

{- | Return the value inside a 'PDEither' if it's a 'PDLeft', error otherwise.

@since WIP
-}
pdfromLeft ::
  forall (a :: S -> Type) (b :: S -> Type) (s :: S).
  PIsData a =>
  Term s (PEitherData a b :--> a)
pdfromLeft = phoistAcyclic $ plam $ \t ->
  pmatch t $ \case
    PDLeft x -> pfromData x
    PDRight _ -> ptraceInfoError "pdfromLeft: unexpected PDRight"

{- | As 'pdfromLeft', but yields a value if given a 'PDRight' instead.

@since WIP
-}
pdfromRight ::
  forall (a :: S -> Type) (b :: S -> Type) (s :: S).
  PIsData b =>
  Term s (PEitherData a b :--> b)
pdfromRight = phoistAcyclic $ plam $ \t ->
  pmatch t $ \case
    PDRight x -> pfromData x
    PDLeft _ -> ptraceInfoError "pdfromRight: unexpected PDLeft"
