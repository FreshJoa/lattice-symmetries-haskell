{-# LANGUAGE RankNTypes #-}

module LatticeSymmetries.Utils
  ( loopM,
    iFoldM,
    logDebug',
    logInfo',
    logError',
    ls_hs_fatal_error,
  )
where

import Colog
import Foreign.C.String
import System.IO.Unsafe (unsafePerformIO)

loopM :: Monad m => i -> (i -> Bool) -> (i -> i) -> (i -> m ()) -> m ()
loopM i₀ cond inc action = go i₀
  where
    go !i
      | cond i = do () <- action i; go (inc i)
      | otherwise = pure ()
{-# INLINE loopM #-}

iFoldM :: Monad m => i -> (i -> Bool) -> (i -> i) -> a -> (a -> i -> m a) -> m a
iFoldM i₀ cond inc x₀ action = go x₀ i₀
  where
    go !x !i
      | cond i = do !x' <- action x i; go x' (inc i)
      | otherwise = pure x
{-# INLINE iFoldM #-}

defaultLogAction :: LogAction IO Message
defaultLogAction = cmap fmtMessage logTextStderr

currentLogAction :: IORef (LogAction IO Message)
currentLogAction = unsafePerformIO $ newIORef defaultLogAction
{-# NOINLINE currentLogAction #-}

withDefaultLogger :: HasCallStack => LoggerT Message IO () -> IO ()
withDefaultLogger f = withFrozenCallStack $ do
  logAction <- readIORef currentLogAction
  usingLoggerT logAction f

logDebug' :: HasCallStack => Text -> IO ()
logDebug' t = withFrozenCallStack $ withDefaultLogger (logDebug t)

logInfo' :: HasCallStack => Text -> IO ()
logInfo' t = withFrozenCallStack $ withDefaultLogger (logInfo t)

logError' :: HasCallStack => Text -> IO ()
logError' t = withFrozenCallStack $ withDefaultLogger (logError t)

ls_hs_fatal_error :: HasCallStack => CString -> CString -> IO ()
ls_hs_fatal_error c_func c_msg = withFrozenCallStack $ do
  func <- fromString <$> peekCString c_func
  msg <- fromString <$> peekCString c_msg
  logError' $ "[" <> func <> "] " <> msg
  exitFailure
