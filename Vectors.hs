{-# LANGUAGE DeriveFunctor #-}

module Vectors where

import Control.Applicative


data Vec3 a = Vec3 a a a
  deriving (Show, Eq, Functor)
data Vec4 a = Vec4 a a a a
  deriving (Show, Eq, Functor)

instance Applicative Vec3 where
  pure x = Vec3 x x x
  Vec3 f g h <*> Vec3 x y z = Vec3 (f x) (g y) (h z)
instance Applicative Vec4 where
  pure x = Vec4 x x x x
  Vec4 f g h i <*> Vec4 x y z w = Vec4 (f x) (g y) (h z) (i w)
  

fromList3d :: [a] -> Vec3 a
fromList3d (x:y:z:_) = Vec3 x y z

fromList4d :: [a] -> Vec4 a
fromList4d (x:y:z:w:_) = Vec4 x y z w


coord4dw :: Vec4 a -> a
coord4dw (Vec4 x y z w) = w

coord4dxyz :: Vec4 a -> Vec3 a
coord4dxyz (Vec4 x y z w) = Vec3 x y z

plus3d :: (Num a) => Vec3 a -> Vec3 a -> Vec3 a
plus3d = liftA2 (+)

plus4d :: (Num a) => Vec4 a -> Vec4 a -> Vec4 a
plus4d = liftA2 (+)

smult3d :: (Num a) => a -> Vec3 a -> Vec3 a
smult3d s = fmap (s*)

smult4d :: (Num a) => a -> Vec4 a -> Vec4 a
smult4d s = fmap (s*)

norm3d :: (Floating a) => Vec3 a -> a
norm3d v = sqrt $ dot3d v v

normalize3d :: (Floating a) => Vec3 a -> Vec3 a
normalize3d a = fmap (/norm3d a) a

dot3d :: (Num a) => Vec3 a -> Vec3 a -> a
dot3d (Vec3 x1 y1 z1) (Vec3 x2 y2 z2) =
  x1*x2 + y1*y2 + z1*z2

cross :: (Num a) => Vec3 a -> Vec3 a -> Vec3 a
cross (Vec3 x1 y1 z1) (Vec3 x2 y2 z2) =
  Vec3 (y1*z2-y2*z1) (z1*x2-z2*x1) (x1*y2-x2*y1)

-- normal vector on a plane through three points
planeNormal :: (Floating a) => Vec3 a -> Vec3 a -> Vec3 a -> Vec3 a
planeNormal a b c = normalize3d $ liftA2 (-) b a `cross` liftA2 (-) c b

rot :: (Floating a) => a -> (a, a) -> (a, a)
rot a (x, y) = (c * x + s * y, -s * x + c * y)
  where
    c = cos a
    s = sin a

rot3dxy :: (Floating a) => a -> Vec3 a -> Vec3 a
rot3dxy a (Vec3 x y z) = Vec3 x' y' z
  where (x', y') = rot a (x, y)

rot3dxz :: (Floating a) => a -> Vec3 a -> Vec3 a
rot3dxz a (Vec3 x y z) = Vec3 x' y z'
  where (x', z') = rot a (x, z)

rot4dyw :: (Floating a) => a -> Vec4 a -> Vec4 a
rot4dyw a (Vec4 x y z w) = Vec4 x y' z w'
  where (y', w') = rot a (y, w)

rot4dxy :: (Floating a) => a -> Vec4 a -> Vec4 a
rot4dxy a (Vec4 x y z w) = Vec4 x' y' z w
  where (x', y') = rot a (x, y)

rot4dzw :: (Floating a) => a -> Vec4 a -> Vec4 a
rot4dzw a (Vec4 x y z w) = Vec4 x y z' w'
  where (z', w') = rot a (z, w)
