module Handler.Admin where

import Import

import Control.Monad (filterM, forM_)
import qualified Data.Text as T
import qualified Data.Set as S
import Database.Persist.Sql (rawExecute)

import Explore (checkTheorem)
import Handler.Helpers
import Logic (counterexamples, converse)
import Models
import Presenter.Theorem (theoremName)

#ifdef DEVELOPMENT
import Data.Time (getCurrentTime)
import DB (flushDeductions)
#else
import Network.HTTP.Types (unauthorized401)
#endif

getAdminR :: Handler Html
getAdminR = render "Admin" $(widgetFile "admin/show")

postExploreR :: Handler Html
postExploreR = do
  before <- runDB $ count ([] :: [Filter Trait])
  theorems <- runDB $ selectList [] []
  mapM_ (checkTheorem "Checking all theorems" . entityKey) theorems
  after <- runDB $ count ([] :: [Filter Trait])
  flash Success $ "Explored all theorems. Found " <> (T.pack . show $ (after - before)) <> " new traits."
  redirect AdminR

postContradictionsR :: Handler Html
postContradictionsR = do
  theorems <- runDB $ selectList [] []
  counters <- mapM (counterexamples . theoremImplication . entityVal) $ theorems
  let pairs = filter (not . S.null . snd) $ zip theorems counters
  properties <- theoremPrefetch . map (entityVal . fst) $ pairs
  render "Contradictions" $(widgetFile "admin/check")

postResetR :: Handler Html
postResetR = do
#ifdef DEVELOPMENT
  flushDeductions
  flash Warning "Reset deduced theorems"
#else
  flash Danger "Can only reset in development mode"
#endif
  redirect AdminR

postTestResetR :: Handler Value
postTestResetR = do
#ifdef DEVELOPMENT
  now <- liftIO getCurrentTime

  runDB $ rawExecute "TRUNCATE struts, assumptions, supporters, proofs, revisions, theorem_properties, traits, properties, spaces, theorems, emails, remote_users RESTART IDENTITY CASCADE" []

  (Entity boolId _) <- runDB . getBy404 $ UValueSetName "boolean"

  _ <- runDB $ do
    insert_ $ User "admin" (Just "admin") True  now now
    insert_ $ User "user"  (Just "user" ) False now now

    forM_ ([1..100] :: [Integer])$ \n -> do
      let n' = T.pack $ show n
      insert_ $ Space ("Space " <> n') (Textarea "-") now now Nothing
      insert_ $ Property ("Property " <> n') [] (Textarea "-") boolId now now

  returnJson $ object [ "status" .= ("Ok" :: Text) ]
#else
  sendResponseStatus unauthorized401 $ object [ "error" .= ("Cannot reset database" :: Text) ]
#endif

progressRow :: Entity Space -> Widget
progressRow (Entity _id s) = do
  known <- handlerToWidget . runDB $ count [TraitSpaceId ==. _id]
  unproven <- handlerToWidget . runDB $ count [TraitSpaceId ==. _id, TraitDeduced ==. False, TraitDescription ==. Textarea ""]
  [whamlet|<tr><td><a href=@{SpaceR _id}>#{spaceName s}</a></td><td>#{known}</td><td>#{unproven}</td>|]

theoremUnknownReversables :: Handler [Entity Theorem]
theoremUnknownReversables = do
  ts <- runDB $ selectList [] [Asc TheoremId]
  -- n+1
  filterM interesting $ ts
  where
    interesting (Entity _id t) = do
      if null . theoremConverseIds $ t
        then do
          cxs <- counterexamples . converse . theoremImplication $ t
          return . S.null $ cxs
        else return False

getTraitProgressR :: Handler Html
getTraitProgressR = do
  spaces <- runDB $ selectList [] [Asc SpaceName]
  render "Trait Progress" $(widgetFile "admin/trait_progress")

getTheoremProgressR :: Handler Html
getTheoremProgressR = do
  unprovenTheorems <- runDB $ selectList [TheoremDescription ==. Textarea ""] [Asc TheoremId]
  reversables <- theoremUnknownReversables
  properties <- theoremPrefetch . map entityVal $ unprovenTheorems ++ reversables
  render "Theorem Progress" $(widgetFile "admin/theorem_progress")
