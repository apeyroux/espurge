{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Main where

import           Control.Concurrent.Async
import           Control.Monad.Catch
import           Control.Monad.Error.Class
import           Control.Monad.IO.Class
import           Data.Aeson
import qualified Data.ByteString.Lazy as LBS
import qualified Data.ByteString.Lazy.Char8 as LBSC8
import           Data.Monoid ((<>))
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import           Database.V5.Bloodhound
import           GHC.Generics
import           Network.HTTP.Client
import           Network.HTTP.Client.TLS
import           Options.Applicative

data Instance = Instance {
  iName :: String
  , iUrl :: String
  , iEsLogin :: String
  , iEsPassword :: String
  , iSnaps :: [String]
  } deriving (Generic, Show, Eq)

instance FromJSON Instance where
  parseJSON (Object v) = Instance
    <$> v .: "instancename"
    <*> v .: "instanceurl"
    <*> v .: "eslogin"
    <*> v .: "espassword"
    <*> v .: "snaps"

newtype OptArgs = OptArgs {
  oaInventaire :: FilePath
 } deriving (Show)

parseArgs :: Parser OptArgs
parseArgs = OptArgs <$>
            strOption
            (long "inventaire"
             <> short 'i'
             <> metavar "FILE"
             <> value "inventaire.json")

listRepo :: Either EsError [GenericSnapshotRepo] -> [SnapshotRepoName]
listRepo (Left _) = []
listRepo (Right ls) = map (\r -> SnapshotRepoName { snapshotRepoName = snapshotRepoName (gSnapshotRepoName r) }) ls

purgeInstance :: Instance -> IO ()
purgeInstance i = do
  let srvES = Server ("https://" <> T.pack (iEsLogin i) <> ":" <> T.pack (iEsPassword i) <> "@" <> T.pack (iUrl i) <> "/es")
  let runBH' = withBH (tlsManagerSettings { managerResponseTimeout = responseTimeoutNone }) srvES
  -- srepos <- runBH' $ getSnapshotRepos AllSnapshotRepos
  -- print srepos
  -- lsnaps <- runBH' $ getSnapshots (SnapshotRepoName (T.pack $ iName i)) AllSnapshots
  mapM_ (\s -> do
            putStrLn $ "Start delete " <> s
            r <- runBH' $ deleteSnapshot (SnapshotRepoName (T.pack $ iName i)) (SnapshotName (T.pack s))
            putStrLn $ "End delete " <> s
        ) (iSnaps i)

main :: IO ()
main = do
  args <- execParser (info parseArgs fullDesc)
  li <- eitherDecodeFileStrict (oaInventaire args) :: IO (Either String [Instance])
  case li of
    Left e -> putStrLn $ "I cant decode inventaire file " <> e
    Right instances -> do
      mapConcurrently_ (\i -> do
                           putStrLn $ "Lancement du traitement de " <> iName i <> " ..."
                           purgeInstance i
                       ) instances

