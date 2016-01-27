{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GADTs             #-}
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE TemplateHaskell   #-}

module Handlers
  ( HomeR
  , PropertiesR
  , SearchR
  , home
  , allProperties
  , search
  , assertTrait
  , showTrait
  ) where

import Base

import Data.Aeson (encode)
import Data.Aeson.TH
import Data.ByteString.Lazy (ByteString)
import qualified Data.Map as M
import Database.Persist
import Database.Persist.Sql
import Servant

import Models
import Actions
import Util

data HomeR = HomeR
  { hrenvironment :: Environment
  , hrstatus :: Text
  , hrmessage :: Text
  , hrsize :: Int
  } deriving (Show)
$(deriveToJSON defaultOptions { fieldLabelModifier = drop 2} ''HomeR)

data PropertiesR = PropertiesR
  { prproperties :: [Entity Property]
  }
$(deriveToJSON defaultOptions { fieldLabelModifier = drop 2} ''PropertiesR)

data SearchR = SearchR
  { srspaces :: [Entity Space]
  }
$(deriveToJSON defaultOptions { fieldLabelModifier = drop 2} ''SearchR)

halt :: ServantErr -> Action a
halt err = Action . lift . left $ err'
  where
    err' = err
      { errBody    = encode err
      , errHeaders = [("Content-Type", "application/json")]
      }

invalid :: ByteString -> Action a
invalid msg = halt $ err422 { errBody = msg }

require :: ByteString -> Maybe a -> Action a
require msg mval = maybe (invalid msg) return mval

home :: Action HomeR
home = do
  hrenvironment <- asks getEnv
  let hrstatus  = "ok"
  let hrmessage = "running"
  universe <- getUniverse
  let hrsize = length $ uspaces universe
  return HomeR{..}

allProperties :: Action PropertiesR
allProperties = do
  prproperties <- runDB $ selectList ([] :: [Filter Property]) []
  return PropertiesR{..}

search :: Text -> Maybe SearchType -> MatchMode -> Action SearchR
search q mst mm = do
  srspaces <- case mst of
    Just ByText -> searchByText q
    _ -> do
      -- TODO: more informative failure message
      f <- require "Could not parse formula from `q`" $ decodeText q
      searchByFormula f mm
  return SearchR{..}

traitExists :: Universe -> SpaceId -> PropertyId -> Bool
traitExists u sid pid = M.member pid $ attributes u sid

attributes :: Universe -> SpaceId -> Properties
attributes u sid = fromMaybe M.empty $ M.lookup sid $ uspaces u

withUser :: (Entity User -> Action a) -> AuthToken -> Action a
withUser f (AuthToken tok) = do
  -- FIXME: proper tokens
  us <- runDB $ selectList [UserIdent ==. decodeUtf8 tok] []
  case us of
    u:_ -> f u
    _   -> halt $ err403 { errBody = "Invalid token" }

assertTrait :: SpaceId -> PropertyId -> Maybe TValueId -> Maybe Text -> AuthToken -> Action Trait
assertTrait sid pid mvid mdesc = withUser $ \user -> do
  u <- getUniverse
  when (traitExists u sid pid) $ invalid "Trait already exists"

  vid  <- require "`value` is required" mvid
  desc <- require "`description` is required" mdesc

  -- Update universe
  -- Update DB
  -- Check for deductions
  error "Not implemented"

get404 :: (PersistEntity b, PersistEntityBackend b ~ SqlBackend) => Key b -> Action b
get404 _id = do
  found <- runDB $ get _id
  case found of
    Nothing -> halt err404
    Just  r -> return r

showTrait :: TraitId -> Action Trait
showTrait = get404
