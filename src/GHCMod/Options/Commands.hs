module GHCMod.Options.Commands where

import Options.Applicative
import Options.Applicative.Types
import Language.Haskell.GhcMod.Types
import GHCMod.Options.DocUtils
import Language.Haskell.GhcMod.Read

type Symbol = String
type Expr = String
type Module = String
type Line = Int
type Col = Int
type Point = (Line, Col)

data GhcModCommands =
    CmdLang
  | CmdFlag
  | CmdDebug
  | CmdBoot
  | CmdNukeCaches
  | CmdRoot
  | CmdLegacyInteractive
  | CmdModules Bool
  | CmdDumpSym FilePath
  | CmdFind Symbol
  | CmdDoc Module
  | CmdLint LintOpts FilePath
  | CmdBrowse BrowseOpts [Module]
  | CmdDebugComponent [String]
  | CmdCheck [FilePath]
  | CmdExpand [FilePath]
  | CmdInfo FilePath Symbol
  | CmdType FilePath Point
  | CmdSplit FilePath Point
  | CmdSig FilePath Point
  | CmdAuto FilePath Point
  | CmdRefine FilePath Point Expr

commandsSpec :: Parser GhcModCommands
commandsSpec =
  hsubparser (
       command "lang" (
          info (pure CmdLang)
          (progDesc "List all known GHC language extensions"))
    <> command "flag" (
          info (pure CmdFlag)
          (progDesc "List GHC -f<foo> flags"))
    <> command "debug" (
          info (pure CmdDebug)
          (progDesc
            "Print debugging information. Please include the output in any bug\
            \ reports you submit"))
    <> command "debug-component" (
          info debugComponentArgSpec
          (progDesc "Debugging information related to cabal component resolution"))
    <> command "boot" (
          info (pure CmdBoot)
          (progDesc "Internal command used by the emacs frontend"))
    -- <> command "nuke-caches" (
    --       info (pure CmdNukeCaches) idm)
    <> command "root" (
          info (pure CmdRoot)
          (progDesc
            "Try to find the project directory. For Cabal projects this is the\
            \ directory containing the cabal file, for projects that use a cabal\
            \ sandbox but have no cabal file this is the directory containing the\
            \ cabal.sandbox.config file and otherwise this is the current\
            \ directory"
          ))
    <> command "legacy-interactive" (
          info (pure CmdLegacyInteractive)
          (progDesc "ghc-modi compatibility mode"))
    <> command "list" (
          info modulesArgSpec
          (progDesc "List all visible modules"))
    <> command "modules" (
          info modulesArgSpec
          (progDesc "List all visible modules"))
    <> command "dumpsym" (
          info dumpSymArgSpec idm)
    <> command "find" (
          info findArgSpec
          (progDesc "List all modules that define SYMBOL"))
    <> command "doc" (
          info docArgSpec
          (progDesc "Try finding the html documentation directory for the given MODULE"))
    <> command "lint" (
          info lintArgSpec
          (progDesc "Check files using `hlint'"))
    <> command "browse" (
          info browseArgSpec
          (progDesc "List symbols in a module"))
    <> command "check" (
          info checkArgSpec
          (progDesc "Load the given files using GHC and report errors/warnings,\
                    \ but don't produce output files"))
    <> command "expand" (
          info expandArgSpec
          (progDesc "Like `check' but also pass `-ddump-splices' to GHC"))
    <> command "info" (
          info infoArgSpec
          (progDesc
            "Look up an identifier in the context of FILE (like ghci's `:info')\
            \ MODULE is completely ignored and only allowed for backwards\
            \ compatibility"))
    <> command "type" (
          info typeArgSpec
          (progDesc "Get the type of the expression under (LINE,COL)"))
    <> command "split" (
          info splitArgSpec
          (progDesc
            "Split a function case by examining a type's constructors"
          <> desc [
            text "For example given the following code snippet:"
          , code [
              "f :: [a] -> a"
            , "f x = _body"
            ]
          , text "would be replaced by:"
          , code [
              "f :: [a] -> a"
            , "f [] = _body"
            , "f (x:xs) = _body"
            ]
          , text "(See https://github.com/kazu-yamamoto/ghc-mod/pull/274)"
          ]))
    <> command "sig" (
          info sigArgSpec
          (progDesc
            "Generate initial code given a signature"
          <> desc [
            text "For example when (LINE,COL) is on the signature in the following\
            \ code snippet:"
            , code ["func :: [a] -> Maybe b -> (a -> b) -> (a,b)"]
            , text "ghc-mod would add the following on the next line:"
            , code ["func x y z f = _func_body"]
            , text "(See: https://github.com/kazu-yamamoto/ghc-mod/pull/274)"
            ]
          ))
    <> command "auto" (
          info autoArgSpec
          (progDesc "Try to automatically fill the contents of a hole"))
    <> command "refine" (
          info refineArgSpec
          (progDesc
            "Refine the typed hole at (LINE,COL) given EXPR"
          <> desc [
            text "For example if EXPR is `filter', which has type `(a -> Bool) -> [a]\
              \ -> [a]' and (LINE,COL) is on the hole `_body' in the following\
              \ code snippet:"
          , code [
                "filterNothing :: [Maybe a] -> [a]"
              , "filterNothing xs = _body"
              ]
          , text "ghc-mod changes the code to get a value of type `[a]', which\
            \ results in:"
          , code [ "filterNothing xs = filter _body_1 _body_2" ]
          , text "(See also: https://github.com/kazu-yamamoto/ghc-mod/issues/311)"
          ]
          ))
    )

strArg :: String -> Parser String
strArg = argument str . metavar

filesArgsSpec :: ([String] -> b) -> Parser b
filesArgsSpec x = x <$> some (strArg "FILES..")

locArgSpec :: (String -> (Int, Int) -> b) -> Parser b
locArgSpec x = x <$>
  strArg "FILE" <*>
  ( (,) <$>
    argument int (metavar "LINE") <*>
    argument int (metavar "COL")
  )

modulesArgSpec, dumpSymArgSpec, docArgSpec, findArgSpec,
  lintArgSpec, browseArgSpec, checkArgSpec, expandArgSpec,
  infoArgSpec, typeArgSpec, autoArgSpec, splitArgSpec,
  sigArgSpec, refineArgSpec, debugComponentArgSpec :: Parser GhcModCommands

modulesArgSpec = CmdModules <$>
  switch (
        long "detailed" <>
        short 'd' <>
        help "Print package modules belong to"
      )
dumpSymArgSpec = CmdDumpSym <$> strArg "TMPDIR"
findArgSpec = CmdFind <$> strArg "SYMBOL"
docArgSpec = CmdDoc <$> strArg "MODULE"
lintArgSpec = CmdLint <$>
  (LintOpts <$> many (strOption (
    long "hlintOpt" <>
    short 'h' <>
    help "Option to be passed to hlint"
  ))) <*> strArg "FILE"
browseArgSpec = CmdBrowse <$>
  (BrowseOpts <$>
    switch (
      long "operators" <>
      short 'o' <>
      help "Also print operators"
    ) <*> -- optOperators      = False
    switch (
      long "detailed" <>
      short 'd' <>
      help "Print symbols with accompanying signature"
    ) <*> -- optDetailed       = False
    switch (
      long "qualified" <>
      short 'q' <>
      help "Qualify symbols"
    )) <*> some (strArg "MODULE")
debugComponentArgSpec = filesArgsSpec CmdDebugComponent
checkArgSpec = filesArgsSpec CmdCheck
expandArgSpec = filesArgsSpec CmdExpand
infoArgSpec = CmdInfo <$>
    strArg "FILE" <*>
    strArg "SYMBOL"
typeArgSpec = locArgSpec CmdType
autoArgSpec = locArgSpec CmdAuto
splitArgSpec = locArgSpec CmdSplit
sigArgSpec = locArgSpec CmdSig
refineArgSpec = locArgSpec CmdRefine <*> strArg "SYMBOL"

int :: ReadM Int
int = do
  v <- readerAsk
  maybe (readerError $ "Not a number \"" ++ v ++ "\"") return $ readMaybe v
