{-# LANGUAGE ScopedTypeVariables #-}

module Render where

import qualified Data.IntSet as ISet
import qualified Data.Set as Set
import qualified Data.IntMap as IMap
import qualified Data.Map.Strict as Map
import Data.List (find)
import Data.Maybe (isJust, fromJust)

import Solids
import Vectors


allTriangles :: Solid p -> [(p, p, p)]
allTriangles (Solid ps) =
  map (\[a, b, c] -> (a, b, c)) $ choose 3 ps

choose :: Int -> [a] -> [[a]]
choose n l = map fst $ choose' n l

choose' :: Int -> [a] -> [([a], [a])]
choose' 0 xs = [([], xs)]
choose' n [] = []
choose' n (x:xs) =
  map (\(chosen, rest) -> (x:chosen, rest)) (choose' (n-1) xs)
  ++ map (\(chosen, rest) -> (chosen, x:rest)) (choose' n xs)


boundingTriangles :: forall a. (Floating a, Ord a) =>
  Solid (Vec3 a) -> [(Vec3 a, Vec3 a, Vec3 a)]
boundingTriangles = last . boundingTrianglesSequence

boundingTrianglesSequence :: forall a. (Floating a, Ord a) =>
  Solid (Vec3 a) -> [[(Vec3 a, Vec3 a, Vec3 a)]]
boundingTrianglesSequence =
  map extractTriangles . esSequence

esSequence :: forall a. (Floating a, Ord a) =>
  Solid (Vec3 a) -> [ElaborateSolid (Vec3 a) (Vec3 a, a)]
esSequence = esSequence' innerPoint mkPlane planeTest
  where
    mkPlane (a, b, c) =
      let normal = planeNormal a b c
      in (normal, normal `dot3d` a)
    planeTest :: (Vec3 a, a) -> Vec3 a -> Bool
    planeTest (normal, value) a = normal `dot3d` a <= value
    innerPoint (a, b, c, d) =
      if tetrahedronVolume a b c d > 10**(-5)
      then Just $ (1/4) `smult3d` foldl1 plus3d [a, b, c, d]
      else Nothing

esSequence' :: ((p, p, p, p) -> Maybe p)
  -> ((p, p, p) -> plane) -> (plane -> p -> Bool)
  -> Solid p -> [ElaborateSolid p plane]
esSequence' innerPoint mkPlane planeTest (Solid allPoints) =
  case mStartPoints of
    Nothing -> [emptyES]
    Just ([a, b, c, d], ps) ->
      myIterate
        (addPoint mkPlane planeTest)
        (initialES mkPlane planeTest
           (fromJust $ innerPoint (a, b, c, d)) a b c d)
        ps
  where
    mStartPoints = findQuadruple
      (\[a, b, c, d] -> isJust (innerPoint (a, b, c, d)))
      allPoints

findQuadruple :: ([p] -> Bool)
  -> [p] -> Maybe ([p], [p])
findQuadruple t = find (t . fst) . choose' 4

myIterate :: (a -> b -> a) -> a -> [b] -> [a]
myIterate f a [] = [a]
myIterate f a (b:bs) = a : myIterate f (f a b) bs

extractTriangles :: ElaborateSolid p plane -> [(p, p, p)]
extractTriangles es =
  map (toTriple . map (vertices es IMap.!) . faceIdToList)
  . Map.keys . faces
  $ es


-- a 3d solid with a triangulation of the surface
data ElaborateSolid p plane = ElaborateSolid
  { vertices :: IMap.IntMap p
  , faces :: Map.Map FaceId (FaceData plane)
  , nextVertId :: VertId
  , center :: p
  }

type VertId = IMap.Key

data EdgeId = EdgeIdRaw VertId VertId
  deriving (Show, Eq, Ord)

mkEdgeId :: VertId -> VertId -> EdgeId
mkEdgeId a b | a <= b     = EdgeIdRaw a b
             | otherwise  = EdgeIdRaw b a

edgeIdToList :: EdgeId -> [VertId]
edgeIdToList (EdgeIdRaw a b) = [a, b]

data FaceId = FaceIdRaw VertId VertId VertId
  deriving (Show, Eq, Ord)

mkFaceId :: VertId -> VertId -> VertId -> FaceId
mkFaceId a b c | a <= b && b <= c = FaceIdRaw a b c
               | a > b            = mkFaceId b a c
               | otherwise        = mkFaceId a c b

faceIdToList :: FaceId -> [VertId]
faceIdToList (FaceIdRaw a b c) = [a, b, c]

faceToEdges :: FaceId -> [EdgeId]
faceToEdges = map fst . faceToEdges'

faceToEdges' :: FaceId -> [(EdgeId, VertId)]
faceToEdges' (FaceIdRaw a b c) =
  [ (mkEdgeId a b, c)
  , (mkEdgeId a c, b)
  , (mkEdgeId b c, a)
  ]

type EdgeData = (FaceId, FaceId)
type FaceData plane = (plane, Bool)

toTriple :: [a] -> (a, a, a)
toTriple [a, b, c] = (a, b, c)
toTriple _ = error "toTriple: not a length 3 list"

fromPair :: (a, a) -> [a]
fromPair (a, b) = [a, b]

emptyES :: ElaborateSolid p plane
emptyES = ElaborateSolid IMap.empty Map.empty 0 undefined

initialES :: ((p, p, p) -> plane) -> (plane -> p -> Bool) -> p
  -> p -> p -> p -> p -> ElaborateSolid p plane
initialES mkPlane planeTest centerPoint a0 b0 c0 d0 = ElaborateSolid
  { vertices = verts
  , faces = Map.fromList
      . map ( \ ([a, b, c], [d]) ->
        let pl = mkPlane . toTriple . map (verts IMap.!) $ [a, b, c]
        in (mkFaceId a b c, (pl, planeTest pl (verts IMap.! d)))
        )
      $ choose' 3 vertIds
  , nextVertId = length vertIds
  , center = centerPoint
  }
  where
    verts = IMap.fromList $ zip vertIds [a0, b0, c0, d0]
    vertIds = [0..3]

addPoint :: forall p plane.
  ((p, p, p) -> plane) -> (plane -> p -> Bool)
  -> ElaborateSolid p plane -> p -> ElaborateSolid p plane
addPoint mkPlane planeTest oldSolid newPoint =
  ElaborateSolid
    newVerts
    newFaces
    (nextVertId oldSolid +1)
    (center oldSolid)
  where
    lookupVert :: VertId -> p
    lookupVert k
      | k == newVertId = newPoint
      | otherwise                = vertices oldSolid IMap.! k
    lookupFace k = faces oldSolid Map.! k
    newVertId = nextVertId oldSolid

    edgeSetToVertSet :: Set.Set EdgeId -> ISet.IntSet
    edgeSetToVertSet = ISet.fromList . concatMap edgeIdToList . Set.toList

    oldVerts = vertices oldSolid
    newVerts = IMap.union keepVerts maybeNewVert
    maybeNewVert = if Map.null dropFaces
      then IMap.empty
      else IMap.singleton newVertId newPoint
    keepVerts :: IMap.IntMap p
    keepVerts =
      IMap.fromSet (vertices oldSolid IMap.!)
      . ISet.fromList . concatMap faceIdToList
      $ Map.keys keepFaces
    keepFaces :: Map.Map FaceId (FaceData plane)
    dropFaces :: Map.Map FaceId (FaceData plane)
    (keepFaces, dropFaces) = Map.partition
      (\(pl, inside) -> planeTest pl newPoint == inside)
      (faces oldSolid)
    criticalEdges :: Set.Set EdgeId
    criticalEdges = Set.intersection
      (edgesOfFaces keepFaces)
      (edgesOfFaces dropFaces)
    edgesOfFaces :: Map.Map FaceId a -> Set.Set EdgeId
    edgesOfFaces = Set.fromList . concatMap faceToEdges . Map.keys
    newFaces :: Map.Map FaceId (FaceData plane)
    newFaces = Map.union keepFaces . Map.fromList
      . map (\(EdgeIdRaw a b) ->
          ( mkFaceId a b newVertId
          , let pl = mkPlane
                  ( oldVerts IMap.! a
                  , oldVerts IMap.! b
                  , newPoint )
            in (pl, planeTest pl (center oldSolid))))
      . Set.toList $ criticalEdges
