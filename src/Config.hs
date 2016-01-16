{-# LANGUAGE OverloadedStrings #-}
module Config
  ( mkLogger
  , mkPool
  ) where

import Control.Monad.Logger                 (runNoLoggingT, runStdoutLoggingT)
import Database.Persist.Postgresql          (ConnectionPool, ConnectionString,
                                             createPostgresqlPool)
import Network.Wai.Middleware.RequestLogger (logStdoutDev, logStdout)
import Network.Wai                          (Middleware)

import Types

mkLogger :: Environment -> Middleware
mkLogger Test = id
mkLogger Development = logStdoutDev
mkLogger Production = logStdout

mkPool :: Environment -> IO ConnectionPool
mkPool Test = runNoLoggingT $ createPostgresqlPool (connStr Test) (envPool Test)
mkPool e = runStdoutLoggingT $ createPostgresqlPool (connStr e) (envPool e)

envPool :: Environment -> Int
envPool Test = 1
envPool Development = 1
envPool Production = 8

connStr :: Environment -> ConnectionString
connStr _ = "host=localhost dbname=pi_base_legacy user=james port=5432"