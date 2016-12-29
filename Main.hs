
import Graphics.UI.GLUT
import Data.IORef
import Control.Concurrent (threadDelay)
import Control.Monad
import qualified Data.ByteString as BS

import Solids
import Vectors
import VectorsToGL
import Render
import Construction
import Intersect


data State = State
  { angle :: GLfloat
  }

initialState = State
  { angle = 0
  }

data ShaderLocations = ShaderLocations
  { aNormal :: AttribLocation
  }


main = do
  getArgsAndInitialize
  createWindow "4d solids"
  shaderLocations <- glSetup
  stateRef <- newIORef initialState
  displayCallback       $= (get stateRef >>= display shaderLocations)
  idleCallback          $= Just (idle stateRef)
  mainLoop


glSetup :: IO ShaderLocations
glSetup = do
  depthFunc $= Just Lequal
  vertShaderSource <- BS.readFile "vertshader.sl"
  fragShaderSource <- BS.readFile "fragshader.sl"
  (prog, attLocNormal) <-
    setupShaderProgram vertShaderSource fragShaderSource
  return $ ShaderLocations attLocNormal

setupShaderProgram ::
  BS.ByteString -> BS.ByteString -> IO (Program, AttribLocation)
setupShaderProgram vertSource fragSource = do
  vertShader <- createShader VertexShader
  fragShader <- createShader FragmentShader
  shaderSourceBS vertShader $= vertSource
  shaderSourceBS fragShader $= fragSource
  compileShader vertShader
  compileShader fragShader
  prog <- createProgram
  attachShader prog vertShader
  attachShader prog fragShader
  linkProgram prog
  log <- programInfoLog prog
  putStrLn $ "Yo, " ++ log ++ ", alter!"
  currentProgram $= Just prog
  attLocNormal <- get $ attribLocation prog "aNormal"
  return (prog, attLocNormal)

display :: ShaderLocations -> State -> IO ()
display shaderLocs state = do
  clearColor $= Color4 0 0.2  0 0
  clear [ColorBuffer, DepthBuffer]
  let a = angle state
      tau = 2*pi
  renderSolid shaderLocs
    . fmap (rot3dxz (tau/7) . rot3dxy (tau/9))
    . intersectXYZ
    . fmap (plus4d $ Vec4 0 0 0 (sqrt 3 * sin (a*0.76842)))
    . fmap (rot4dyw (a*3) . rot4dxy (a*0.2) . rot4dzw (a*2.2))
    $ hypercube
  flush

myCube = intersectXYZ hypercube

vertexAttrib3' :: AttribLocation -> Vec3 GLfloat -> IO ()
vertexAttrib3' loc (Vec3 x y z) = vertexAttrib3 loc x y z

renderSolid :: ShaderLocations -> Solid (Vec3 GLfloat) -> IO ()
renderSolid shaderLocs solid = renderPrimitive Triangles $
  mapM_ renderTriangle $ allTriangles solid
  where
    renderTriangle :: (Vec3 GLfloat, Vec3 GLfloat, Vec3 GLfloat) -> IO ()
    renderTriangle (a, b, c) = do
      vertexAttrib3' (aNormal shaderLocs) $ planeNormal a b c
      vertex (toGLVertex3 a)
      vertex (toGLVertex3 b)
      vertex (toGLVertex3 c)

idle :: IORef State -> IO ()
idle ref = do
  threadDelay 30000
  st <- get ref
  ref $= step st
  threadDelay $ 10^4
--  putStrLn "Yo"
  postRedisplay Nothing

step :: State -> State
step s = State (angle s + 0.03)
