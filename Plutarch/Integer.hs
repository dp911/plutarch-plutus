{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Plutarch.Integer (
  -- * Type
  PInteger,

  -- * Type class
  PIntegral (..),

  -- * Functions
  pexpModInteger,
) where

import GHC.Generics (Generic)
import Plutarch.Bool (PEq, POrd, PPartialOrd, pif, (#<), (#<=), (#==))
import Plutarch.Internal (
  S,
  Term,
  phoistAcyclic,
  (#),
  (:-->),
 )
import Plutarch.Internal.Lift (DeriveBuiltinPLiftable, PLiftable, PLifted' (PLifted'), pconstant)
import Plutarch.Internal.Newtype (PlutusTypeNewtype)
import Plutarch.Internal.Other (POpaque, pto)
import Plutarch.Internal.PLam (plam)
import Plutarch.Internal.PlutusType (DPTStrat, DerivePlutusType, PInner, PlutusType)
import Plutarch.Num (PNum, pabs, pfromInteger, pnegate, psignum, (#*), (#+), (#-))
import Plutarch.Unsafe (punsafeBuiltin, punsafeDowncast)
import PlutusCore qualified as PLC

-- | Plutus BuiltinInteger
newtype PInteger s = PInteger (Term s POpaque)
  deriving stock (Generic)
  deriving anyclass (PlutusType)

instance DerivePlutusType PInteger where type DPTStrat _ = PlutusTypeNewtype

-- | @since WIP
deriving via
  (DeriveBuiltinPLiftable PInteger Integer)
  instance
    PLiftable PInteger

class PIntegral a where
  pdiv :: Term s (a :--> a :--> a)
  default pdiv :: PIntegral (PInner a) => Term s (a :--> a :--> a)
  pdiv = phoistAcyclic $ plam $ \x y -> punsafeDowncast $ pdiv # pto x # pto y
  pmod :: Term s (a :--> a :--> a)
  default pmod :: PIntegral (PInner a) => Term s (a :--> a :--> a)
  pmod = phoistAcyclic $ plam $ \x y -> punsafeDowncast $ pmod # pto x # pto y
  pquot :: Term s (a :--> a :--> a)
  default pquot :: PIntegral (PInner a) => Term s (a :--> a :--> a)
  pquot = phoistAcyclic $ plam $ \x y -> punsafeDowncast $ pquot # pto x # pto y
  prem :: Term s (a :--> a :--> a)
  default prem :: PIntegral (PInner a) => Term s (a :--> a :--> a)
  prem = phoistAcyclic $ plam $ \x y -> punsafeDowncast $ prem # pto x # pto y

instance PIntegral PInteger where
  pdiv = punsafeBuiltin PLC.DivideInteger
  pmod = punsafeBuiltin PLC.ModInteger
  pquot = punsafeBuiltin PLC.QuotientInteger
  prem = punsafeBuiltin PLC.RemainderInteger

instance PEq PInteger where
  x #== y = punsafeBuiltin PLC.EqualsInteger # x # y

instance PPartialOrd PInteger where
  x #<= y = punsafeBuiltin PLC.LessThanEqualsInteger # x # y
  x #< y = punsafeBuiltin PLC.LessThanInteger # x # y

instance POrd PInteger

instance PNum PInteger where
  x #+ y = punsafeBuiltin PLC.AddInteger # x # y
  x #- y = punsafeBuiltin PLC.SubtractInteger # x # y
  x #* y = punsafeBuiltin PLC.MultiplyInteger # x # y
  pabs = phoistAcyclic $ plam \x -> pif (x #<= -1) (negate x) x
  pnegate = phoistAcyclic $ plam (0 #-)
  psignum = plam \x ->
    pif
      (x #== 0)
      0
      $ pif
        (x #<= 0)
        (-1)
        1
  pfromInteger = pconstant

{- | Performs modulo exponentiation. More precisely, @pexpModInteger b e m@
performs @b@ to the power of @e@, modulo @m@. The result is always
non-negative.

= Note

This will error if the modulus is zero. When given a negative exponent, this
will try to find a modular multiplicative inverse, and will error if none
exists.

@since WIP
-}
pexpModInteger ::
  forall (s :: S).
  Term s (PInteger :--> PInteger :--> PInteger :--> PInteger)
pexpModInteger = punsafeBuiltin PLC.ExpModInteger
