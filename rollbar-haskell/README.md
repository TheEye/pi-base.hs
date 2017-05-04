rollbar-haskell
===============

send error notifications to rollbar.com

I have used a few different error notification services.

Rollbar has:

  * good support for client-side javascript errors
  * a nice UI 
  * a complete feature set (for me at least)


Usage
=====

Below is some example Yesod code.
Integration should be similar elsewhere:

1) (optional) save Settings at startup
2) have a global exception handler that notifies Rollbar

``` haskell

-- initialization code
-- in Yesod, this is in makeFoundation in Application.hs
    hn <- getHostName
    let rc = Rollbar.Settings
               { Rollbar.environment = Rollbar.Environment $ tshow $ appEnv conf
               , Rollbar.token =
                     Rollbar.ApiToken $ rollbarApiKeyServer $ appExtra conf
               , Rollbar.hostName = hn
               }
    -- put rc into the foundation type

-- using in a global exception handler
-- in Yesod, this is in the Yesod typeclass in Foundation.hs
import qualified Rollbar
import Rollbar.MonadLogger (reportErrorS)

-- Add a field to the foundation data type
data App = App {
    ...
  , appRollbar :: Rollbar.Settings
  }


errorHandler err@(InternalError e) = do
    app <- getYesod
    -- forking means error reporting to Rollbar won't hold up
    -- the response to the client
    unless development $ forkHandler ($logErrorS "errorHandler" . tshow) $ do
        muser <- maybeAuth
        let rollbarPerson (Entity uid user) =
               Rollbar.Person
                 { Rollbar.id       = toPathPiece uid
                 , Rollbar.username = Nothing
                 , Rollbar.email    = Just $ emailToText $ userEmail user
                 }
        let rPerson = fmap rollbarPerson muser
        reportErrorS (appRollbar app)
                     (Rollbar.Options rPerson Nothing)
                     "errorHandler"
                     ($logDebugS) e
    defaultErrorHandler err 

errorHandler err = defaultErrorHandler err
```
