{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Control.Monad.IO.Class
import           Data.Monoid ((<>))
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import           Database.V5.Bloodhound
import           Network.HTTP.Client
import           Options.Applicative

listRepo :: Either EsError [GenericSnapshotRepo] -> [SnapshotRepoName]
listRepo (Left _) = []
listRepo (Right ls) = map (\r -> SnapshotRepoName { snapshotRepoName = snapshotRepoName (gSnapshotRepoName r) }) ls

data OptArgs = OptArgs {
  repo :: T.Text
  , es :: T.Text } deriving (Show)

parseArgs :: Parser OptArgs
parseArgs = OptArgs <$>
            strOption
            (long "repository"
             <> short 'r'
             <> metavar "NAME")
            <*>
            strOption
            (long "server"
             <> short 's'
             <> metavar "URL"
             <> value "http://localhost:9200")

main :: IO ()
main = do
  args <- execParser (info parseArgs fullDesc)
  let srvES = Server (es args)
  let runBH' = withBH (defaultManagerSettings { managerResponseTimeout = responseTimeoutNone }) srvES
  srepos <- runBH' $ getSnapshotRepos AllSnapshotRepos
  lsnaps <- runBH' $ getSnapshots (SnapshotRepoName (repo args)) AllSnapshots
  case lsnaps of
    Left e -> print e
    Right l -> do
      let lx = tail $ reverse l
      print $ length lx
      mapM_ (\s -> do
              let sn = snapshotName (snapInfoName s)
              putStrLn $ "Start delete " <> show sn
              runBH' $ deleteSnapshot (SnapshotRepoName (repo args)) (SnapshotName sn)
              putStrLn $ "End delete " <> show sn
            ) lx
