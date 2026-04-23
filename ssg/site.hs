--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.List (sortBy)
import           Data.Monoid (mappend)
import           Data.Ord (Down(..), comparing)
import           Hakyll
import           System.FilePath (takeBaseName, takeDirectory, (</>))


--------------------------------------------------------------------------------
config :: Configuration
config = defaultConfiguration
    { providerDirectory = "src"
    , storeDirectory    = "ssg/_cache"
    , tmpDirectory      = "ssg/_tmp"
    }

--------------------------------------------------------------------------------
main :: IO ()
main = hakyllWith config $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match "404.html" $ do
        route idRoute
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext

    match "posts/*" $ do
        route $ setExtension "html" `composeRoutes` dirRoute
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    create ["blog.html"] $ do
        route $ constRoute "blog/index.html"
        compile $ do
            posts <- recentFirstByMeta =<< loadAll "posts/*"
            let blogCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Blog"                `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/post-list.html" blogCtx
                >>= loadAndApplyTemplate "templates/default.html" blogCtx
                >>= relativizeUrls


    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirstByMeta =<< loadAll "posts/*"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateBodyCompiler


--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext

-- Route foo/bar.html to foo/bar/index.html for clean URLs
dirRoute :: Routes
dirRoute = customRoute $ \ident ->
    let path = toFilePath ident
        dir  = takeDirectory path
        base = takeBaseName path
    in  dir </> base </> "index.html"

recentFirstByMeta :: (MonadMetadata m) => [Item a] -> m [Item a]
recentFirstByMeta items = do
    dated <- mapM (\i -> do
        meta <- getMetadata (itemIdentifier i)
        let date = lookupString "date" meta
        return (date, i)) items
    return $ map snd $ sortBy (flip $ comparing fst) dated
