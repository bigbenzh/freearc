{-# OPTIONS_GHC -cpp #-}
---------------------------------------------------------------------------------------------------
---- �������� ������ � �����, �������������� FreeArc.                                          ----
---- ������������� ������ ��������� ������.                                                    ----
---- ������������� Lua-��������.                                                               ----
---------------------------------------------------------------------------------------------------
module Options where

import Prelude hiding (catch)
import Control.OldException
import Control.Monad
import Control.Concurrent
import Data.Array
import Data.Bits
import Data.Char
import Data.IORef
import Data.List
import Data.Maybe
import Data.Word
import Foreign.C
import Foreign.C.Types
import System.Environment
import System.IO.Unsafe
import System.Time

import qualified CompressionLib
import Utils
import Files
import Charsets
import Errors
import FileInfo
import Compression


-- |�������� ����������� �������
data Command = Command {
    cmd_args                 :: ![String]           -- ������ ����� �������, �������� �� �����
  , cmd_additional_args      :: ![String]           -- �������������� �����, ����������� �� ���������� ����� � ������-�����
  , cmd_name                 :: !String             -- �������� �������
  , cmd_arcspec              ::  String             -- ����� �������
  , cmd_arclist              ::  [FilePath]         --   ����� ���� ��������� �� ���� ����� (� ��������, ����������) �������
  , cmd_arcname              ::  FilePath           --   ��� ��������������� ������ (�� ����� ������� � wildcards � cmd_arcspec ����������� ��������� ������ � ���������� ������ ��������������� ������)
  , cmd_archive_filter       :: (FileInfo -> Bool)  -- �������� ������ ������ �� ������������ �������
  , cmd_filespecs            :: ![String]           -- ������������ ����������� ������� ��� ������
  , cmd_added_arcnames       :: !(IO [FilePath])    --   ����������, ������������ ����� ����������� ������� (������� "j")
  , cmd_diskfiles            :: !(IO [FileInfo])    --   ����������, ������������ ����� ����������� ������  (��������� ������� ��������/���������� �������)
  , cmd_subcommand           :: !Bool               -- ����������? (��������, ������������ ����� ���������)
  , cmd_setup_command        :: !(IO ())            -- ��������, ������� ���� ��������� ��������������� ����� ������� ��������� ���� ������� (���� ��� �� ��� ������)
                                                    -- �����:
  , opt_scan_subdirs         :: !Bool               --   ����������� ����� ������?
  , opt_add_dir              :: !Bool               --   �������� ��� ������ � ����� ��������, ���� ���������� ����������?
  , opt_add_exclude_path     :: !Int                --   ��������� ��� �������� �������� / ��������� ���������� ���� (��� ������ ������������ ������ �� �����)
  , opt_dir_exclude_path     :: !Int                --   ��������� ��� �������� �������� / ��������� ���������� ���� (��� ������ �������� ������)
  , opt_arc_basedir          :: !String             --   ������� ������� ������ ������
  , opt_disk_basedir         :: !String             --   ������� ������� �� �����
  , opt_group_dir            :: ![Grouping]         --   ����������� ������ ��� �������� ������
  , opt_group_data           :: ![Grouping]         --   ����������� ������ ��� �����-�����
  , opt_data_compressor      :: !UserCompressor     --   ������ ������ ��� ������
  , opt_dir_compressor       :: !Compressor         --   ����� ������ ��� ������ ��������
  , opt_autodetect           :: !Int                --   ������� ����������� ����� ������ (0..9)
  , opt_arccmt_file          :: !String             --   ����, �� �������� �������� (� ������� �������) ����������� � ������
  , opt_arccmt_str           :: !String             --   .. ��� ��� ����������� � ������ ����
  , opt_include_dirs         :: !(Maybe Bool)       --   �������� �������� � ���������? (��/���/�� ���������������)
  , opt_indicator            :: !String             --   ��� ���������� ��������� ("0" - �����������, "1" - ��������� �� ���������, "2" - ����� � ��������� ������ ����� ������� ��������������� �����)
  , opt_display              :: !String             --   ���������� �����, ����������� ����� ������ �������� �� �����
  , opt_overwrite            :: !(IORef String)     --   ��������� ������� � ������������ � ���������� ������ ("a" - �������������� ���, "s" - ���������� ���, ����� ������ - �������� �������)
  , opt_sfx                  :: !String             --   ��� SFX-������, ������� ���� ������������ � ������ ("-" - �����������, ���� ��� ����, "--" - ����������� ������������)
  , opt_keep_time            :: !Bool               --   ��������� mtime ������ ����� ���������� �����������?
  , opt_time_to_last         :: !Bool               --   ���������� mtime ������ �� mtime ������ ������� ����� � ��?
  , opt_keep_broken          :: !Bool               --   �� ������� �����, ������������� � ��������?
  , opt_test                 :: !Bool               --   �������������� ����� ����� ��������?
  , opt_pretest              :: !Int                --   ����� ������������ ������� _�����_ ����������� �������� (0 - ���, 1 - ������ recovery info, 2 - recovery ��� full, 3 - full testing)
  , opt_lock_archive         :: !Bool               --   ������� ����������� ����� �� ���������� ���������?
  , opt_match_with           :: !(PackedFilePath -> FilePath)  -- ������������ ��� ���������� ����� � fpBasename ��� fpFullname
  , opt_append               :: !Bool               --   ��������� ����� ����� ������ � ����� ������?
  , opt_recompress           :: !Bool               --   ������������� ������������ ��� �����?
  , opt_keep_original        :: !Bool               --   �� �������������� �� ������ �����?
  , opt_noarcext             :: !Bool               --   �� ��������� ����������� ���������� � ����� ������?
  , opt_nodir                :: !Bool               --   �� ���������� � ����� ��� ���������� (��� ����������)?
  , opt_nodates              :: !Bool               --   �� ���������� � ����� ���� ����������� ������?
  , opt_update_type          :: !Char               --   �������� ���������� ������ (a/f/u/s)
  , opt_x_include_dirs       :: !Bool               --   �������� �������� � ��������� (��� ������ ��������/����������)?
  , opt_no_nst_filters       :: !Bool               --   TRUE, ���� � ������� ����������� ����� ������ ������ �� �����/�������/������� (-n/-s../-t..)
  , opt_file_filter          :: !(FileInfo -> Bool) --   �������������� ������� �������� ������ ������ �� ���������/�������/�������/����� (��, ����� filespecs)
  , opt_sort_order           :: !String             --   ������� ���������� ������ � ������
  , opt_reorder              :: !Bool               --   ��������������� ����� ����� ���������� (�������� ����� ����������/������� �����)?
  , opt_find_group           :: !(FileInfo -> Int)  --   �������, ������������ �� FileInfo � ����� ������ (�� arc.groups) ��������� ������ ����
  , opt_groups_count         :: !Int                --   ���������� ����� (`opt_find_group` ���������� ���������� � ��������� 0..opt_groups_count-1)
  , opt_find_type            :: !(FileInfo -> Int)  --   �������, ������������ �� FileInfo � ������ ���� ������ (�� ������������� � `opt_data_compressor`) ��������� ������ ����
  , opt_types_count          :: !Int                --   ���������� ����� ������ (`opt_find_type` ���������� ���������� � ��������� 0..opt_types_count-1)
  , opt_group2type           :: !(Int -> Int)       --   ����������� ����� ������ �� arc.groups � ����� ���� ����� �� opt_data_compressor
  , opt_logfile              :: !String             --   ��� ���-����� ��� ""
  , opt_delete_files         :: !DelOptions         --   ������� �����/�������� ����� �������� ���������?
  , opt_create_in_workdir    :: !Bool               --   ������� ����� ������� �� ��������� ��������?
  , opt_clear_archive_bit    :: !Bool               --   �������� ������� Archive � ������� ����������� ������ (� ������, ������� ��� ���� � ������)
  , opt_language             :: !String             --   ����/���� �����������
  , opt_recovery             :: !String             --   �������� Recovery ����� (� ���������, ������ ��� ��������)
  , opt_broken_archive       :: !String             --   ������������ ����������� �����, ��������� �������� ��� � ������� ���������� ���������� ������
  , opt_original             :: !String             --   ������������� � ���������� URL ������� ����� ������
  , opt_save_bad_ranges      :: !String             --   �������� � �������� ���� ������ ����������� ������ ������ ��� �� �����������
  , opt_pause_before_exit    :: !String             --   ������� ����� ����� ������� �� ���������
  , opt_global_queueing      :: !Bool               --   ����� � ���������� ������� ��������?
  , opt_shutdown             :: !Bool               --   ��������� ��������� �� ��������� ������?
  , opt_compression_cache    :: !Int                --   ������ ������ ������������ ������ ��� ������
  , opt_decompression_cache  :: !Int                --   ������ ������ ������������ ������ ��� ����������
  , opt_limit_compression_memory   :: !MemSize      --   ����������� ������ ��� ��������, ����
  , opt_limit_decompression_memory :: !MemSize      --   ����������� ������ ��� ����������, ����
  , opt_volumes              :: ![FileSize]         --   ������� ����� ������������ ������
  , opt_archive_type         :: !String             --   ��� ��������������� ������ (arc/zip/rar/...)
  , opt_archive_extension    :: !String             --   ���������� ������� �� ��������� (.arc/.zip/.rar/...)
  , opt_7z_compression       :: ![String]           --   ��������� ������ ��� 7z.dll

                                                    -- ��������� ����������:
  , opt_encryption_algorithm :: !String             --   �������� ����������.
  , opt_cook_passwords                              --   �������������� ������� � ������������� ����������, ����������� � ������������ ������ � �������� keyfile (�� ������ ����������� ������, ��� ������� ���������� ����� �������, ������� �� ����� ���� ��������� � parseCmdline)
                             :: !(Command -> (ParseDataFunc -> IO String, ParseDataFunc -> IO String, IO ()) -> IO Command)
  , opt_data_password        :: String              --   ������, ������������ ��� ���������� ������ (�������� � ���� ���� � ���������� � ���������� keyfiles). "" - ������������� �� �����
  , opt_headers_password     :: String              --   ������, ������������ ��� ���������� ���������� (ditto)
  , opt_decryption_info                             --   ����������, ������������ ���������� ������� ����� ����������:
                             :: ( Bool              --     �� ����������� � ������������ ����� ������, ���� ���� ��� ��������� ��� ���������� ������ �� ��������?
                                , MVar [String]     --     ������ "������ �������", �������� �� �������� ������������ ��������������� ������
                                , [String]          --     ���������� keyfiles, ����������� � �������
                                , IO String         --     ask_decryption_password
                                , IO ()             --     bad_decryption_password
                                )
  -- �������� ������/������ ������ � ���������, ������������� ������ -sc
  , opt_parseFile   :: !(Domain -> FilePath -> IO [String])      -- ��������� �������� ����� � ������������� � -sc ���������� � ��-����������� ���������� �� ������
  , opt_unParseFile :: !(Domain -> FilePath -> String -> IO ())  -- ��������� ������ ����� � ������������� � -sc ����������
  , opt_parseData   :: !(Domain -> String -> String)             -- ��������� �������� �������� ������ � ������������� � -sc ����������
  , opt_unParseData :: !(Domain -> String -> String)             -- ��������� ���������� ������ ��� ������ � ������������� � -sc ����������
  }


-- |��������� ������ �������, �������� ������������� ��� ����������� ������
get_opt_decryption_passwords command  =  let (_, mvar_passwords, _, _, _) = opt_decryption_info command
                                         in val mvar_passwords

-- |����������� ����� --debug
opt_debug cmd = cmd.$opt_display.$(`contains_one_of` "$#")

-- |�������� ������������ ������?
opt_testMalloc cmd = cmd.$opt_display.$(`contains_one_of` "%")


-- |������������ ����� ������ �� ������� ���������� ������ ������ (���������� ��������������� ����� ������� ���������)
-- � ��������� ������ "tempfile" ����� ������� ������������ �����������
-- (������ �������������� �� �������� -lc � ������� ����������� ����� ��������� ������, ���� �� ������ -lc-)
limit_compression   = limit_de_compression opt_limit_compression_memory   limitCompressionMem

-- |��������� ������ "tempfile" ����� ������� ������������ ����������� ��� ����������
limit_decompression = limit_de_compression opt_limit_decompression_memory limitDecompressionMem

-- |������������ ������ ����������� � ������ Recovery Record �� ������� ���������� ������ ������ (��������� RR ��� �������� �������� ������� � ���)
limit_protection    = limit_de_compression opt_limit_compression_memory   minI

-- Generic algorithm
limit_de_compression option limit_f command method = do
  let memory_limit = command.$option
  if memory_limit==CompressionLib.aUNLIMITED_MEMORY
    then return method
    else do maxMem <- getMaxBlockToAlloc
            return$ limit_f (memory_limit `min` maxMem) method



-- |������ �����, �������������� ����������
optionsList = sortOn (\(OPTION a b _) -> (a|||"zzz",b))
   [OPTION "--"    ""                   "stop processing options"
   ,OPTION "cfg"   "config"            ("use configuration FILES (default: " ++ aCONFIG_FILES ++ ")")
   ,OPTION "env"   ""                  ("read default options from environment VAR (default: " ++ aCONFIG_ENV_VAR ++ ")")
   ,OPTION "r"     "recursive"          "recursively collect files"
   ,OPTION "f"     "freshen"            "freshen files"
   ,OPTION "u"     "update"             "update files"
   ,OPTION ""      "sync"               "synchronize archive and disk contents"
   ,OPTION "o"     "overwrite"          "existing files overwrite MODE (+/-/p)"
   ,OPTION "y"     "yes"                "answer Yes to all queries"
   ,OPTION "x"     "exclude"            "exclude FILESPECS from operation"
   ,OPTION "n"     "include"            "include only files matching FILESPECS"
   ,OPTION "ep"    "ExcludePath"        "Exclude/expand path MODE"
   ,OPTION "ap"    "arcpath"            "base DIR in archive"
   ,OPTION "dp"    "diskpath"           "base DIR on disk"
   ,OPTION "m"     "method"             "compression METHOD (-m0..-m9, -m1x..-m9x)"
   ,OPTION "dm"    "dirmethod"          "compression METHOD for archive directory"
   ,OPTION "ma"    ""                   "set filetype detection LEVEL (+/-/1..9)"
   ,OPTION "md"    "dictionary"         "set compression dictionary to N mbytes"
   ,OPTION "mm"    "multimedia"         "set multimedia compression to MODE"
   ,OPTION "ms"    "StoreCompressed"    "store already compressed files"
   ,OPTION "mt"    "MultiThreaded"      "number of compression THREADS"
   ,OPTION "mc"    ""                   "disable compression algorithms (-mcd-, -mc-rep...)"
   ,OPTION "mx"    ""                   "maximum internal compression mode"
   ,OPTION "max"   ""                   "maximum compression using external precomp, ecm, ppmonstr"
   ,OPTION "ds"    "sort"               "sort files in ORDER"                      -- to do: ������� ��� ����� OptArg
   ,OPTION ""      "groups"             "name of groups FILE"                      -- to do: ������� ��� ����� OptArg
   ,OPTION "s"     "solid"              "GROUPING for solid compression"           -- to do: ������� ��� ����� OptArg
   ,OPTION "p"     "password"           "encrypt/decrypt compressed data using PASSWORD"
   ,OPTION "hp"    "HeadersPassword"    "encrypt/decrypt archive headers and data using PASSWORD"
   ,OPTION "ae"    "encryption"         "encryption ALGORITHM (aes, blowfish, serpent, twofish)"
   ,OPTION "kf"    "keyfile"            "encrypt/decrypt using KEYFILE"
   ,OPTION "op"    "OldPassword"        "old PASSWORD used only for decryption"
   ,OPTION "okf"   "OldKeyfile"         "old KEYFILE used only for decryption"
   ,OPTION "w"     "workdir"            "DIRECTORY for temporary files"
   ,OPTION ""      "create-in-workdir"  "create archive in workdir and then move to final location"
   ,OPTION "sc"    "charset"            "CHARSETS used for listfiles and comment files"
   ,OPTION ""      "language"           "load localisation from FILE"
   ,OPTION "tp"    "pretest"            "test archive before operation using MODE"
   ,OPTION "t"     "test"               "test archive after operation"
   ,OPTION "t"     "type"               "archive TYPE (arc/zip/rar/...)"
   ,OPTION "d"     "delete"             "delete files & dirs after successful archiving"
   ,OPTION "df"    "delfiles"           "delete only files after successful archiving"
   ,OPTION "kb"    "keepbroken"         "keep broken extracted files"
   ,OPTION "ba"    "BrokenArchive"      "deal with badly broken archive using MODE"
   ,OPTION "sm"    "SizeMore"           "select files larger than SIZE"
   ,OPTION "sl"    "SizeLess"           "select files smaller than SIZE"
   ,OPTION "tb"    "TimeBefore"         "select files modified before specified TIME"
   ,OPTION "ta"    "TimeAfter"          "select files modified after specified TIME"
   ,OPTION "tn"    "TimeNewer"          "select files newer than specified time PERIOD"
   ,OPTION "to"    "TimeOlder"          "select files older than specified time PERIOD"
   ,OPTION "k"     "lock"               "lock archive"
   ,OPTION "rr"    "recovery"           "add recovery information of specified SIZE to archive"
   ,OPTION "sfx"   ""                  ("add sfx MODULE (\""++default_sfx aFreeArcExt++"\" by default)")  -- to do: ������� ��� ����� OptArg
   ,OPTION "z"     "arccmt"             "read archive comment from FILE or stdin"  -- to do: ������� ��� ����� OptArg
   ,OPTION ""      "archive-comment"    "input archive COMMENT in cmdline"
   ,OPTION "i"     "indicator"          "select progress indicator TYPE (0/1/2)"   -- to do: ������� ��� ����� OptArg
   ,OPTION "ad"    "adddir"             "add arcname to extraction path"
   ,OPTION "ag"    "autogenerate"       "autogenerate archive name with FMT"       -- to do: ������� ��� ����� OptArg
   ,OPTION ""      "noarcext"           "don't add default extension to archive name"
   ,OPTION "tk"    "keeptime"           "keep original archive time"
   ,OPTION "tl"    "timetolast"         "set archive time to latest file"
   ,OPTION "fn"    "fullnames"          "match with full names"
   ,OPTION ""      "append"             "add new files to the end of archive"
   ,OPTION ""      "recompress"         "recompress archive contents"
   ,OPTION ""      "dirs"               "add empty dirs to archive"
   ,OPTION "ed"    "nodirs"             "don't add empty dirs to archive"
   ,OPTION ""      "nodates"            "don't store filetimes in archive"
   ,OPTION ""      "cache"              "use N mbytes for read-ahead cache"
   ,OPTION "lc"    "LimitCompMem"       "limit memory usage for compression to N mbytes"
   ,OPTION "ld"    "LimitDecompMem"     "limit memory usage for decompression to N mbytes"
   ,OPTION ""      "nodir"              "don't write archive directories"
   ,OPTION ""      "nodata"             "don't store data in archive"
   ,OPTION ""      "crconly"            "save/check CRC, but don't store data"
   ,OPTION "di"    "display"           ("control AMOUNT of information displayed: ["++aDISPLAY_ALL++"]*")
   ,OPTION ""      "logfile"            "duplicate all information displayed to this FILE"
   ,OPTION ""      "print-config"       "display built-in definitions of compression methods"
   ,OPTION ""      "proxy"              "setups proxy(s) for URL access"
   ,OPTION ""      "bypass"             "setups proxy bypass list for URL access"
   ,OPTION ""      "original"           "redownload broken parts of archive from the URL"
   ,OPTION ""      "save-bad-ranges"    "save list of broken archive parts to the FILE"
   ,OPTION ""      "pause-before-exit"  "make a PAUSE just before closing program window"
   ,OPTION "ioff"  "shutdown"           "shutdown computer when operation completed"
   ,OPTION "v"     "volume"             "split archive to volumes each of SIZE bytes"
   ,OPTION ""      "queue"              "queue operations across multiple FreeArc copies"
   ]

-- |������ �����, ������� ����� ������� ��������� ��� ������������� �������� � ������� ��������� ������
aLEAST_PRIORITY_OPTIONS = words ""

-- |������ �����, ������� ���� �������� ������������ ��� ������������� �������� � ������� ��������� ������
aPREFFERED_OPTIONS = words "method sfx charset SizeMore SizeLess overwrite shutdown type"

-- |����� �� ����������� ������, ������� ������������ ��������� :)
aSUPER_PREFFERED_OPTIONS = words "OldKeyfile"

-- |������ ������ � ��������� ������ (����� � ������� � ���)
hidePasswords args = map f args1 ++ args2 where
  (args1,args2)  =  break (=="--") args
  f "-p-"                                   =  "-p-"
  f ('-':'p':_)                             =  "-p"
  f "-op-"                                  =  "-op-"
  f ('-':'o':'p':_)                         =  "-op"
  f "-hp-"                                  =  "-hp-"
  f ('-':'h':'p':_)                         =  "-hp"
  f "--OldPassword-"                        =  "--OldPassword-"
  f x | "--OldPassword" `isPrefixOf` x      =  "--OldPassword"
  f "--HeadersPassword-"                    =  "--HeadersPassword-"
  f x | "--HeadersPassword" `isPrefixOf` x  =  "--HeadersPassword"
  f "--password-"                           =  "--password-"
  f x | "--password" `isPrefixOf` x         =  "--password"
  f x = x


-- |�������� ������, �������������� ����������
commandsList = [
    "a        add files to archive"
  , "c        add comment to archive"
  , "ch       modify archive (recompress, encrypt and so on)"
  , "create   create new archive"
  , "cw       write archive comment to file"
  , "d        delete files from archive"
  , "e        extract files from archive ignoring pathnames"
  , "f        freshen archive"
  , "j        join archives"
  , "k        lock archive"
  , "l        list files in archive"
  , "lb       bare list of files in archive"
  , "lt       technical archive listing"
  , "m        move files and dirs to archive"
  , "mf       move files to archive"
  , "modify   modify archive using +/-/* actions"
  , "r        recover archive using recovery record"
  , "rr       add recovery record to archive"
  , "s        convert archive to SFX"
  , "t        test archive integrity"
  , "u        update files in archive"
  , "v        verbosely list files in archive"
  , "x        extract files from archive"
  ]

-- |������ ������, �������������� ����������
aLL_COMMANDS = map (head.words) commandsList

-- |������ ������, ������� ������ �������� �����
is_COPYING_COMMAND ('r':'r':_) = True
is_COPYING_COMMAND ('s':_)     = True
is_COPYING_COMMAND x           = x `elem` words "c ch d j k"

-- |�������, � ������� �� ������ ���� �� ������ ��������� (������ ����� ������)
is_CMD_WITHOUT_ARGS x  =  is_COPYING_COMMAND x  &&  (x `notElem` words "d j")

-- Self-explained :)
is_CMD_CREATE = (=="create")
is_CMD_MODIFY = (=="modify")

-- |������������� ���� ������ �� ������ �����: ������� ��������, ����������, ������������ � ��������
data CmdType = ADD_CMD | EXTRACT_CMD | TEST_CMD | LIST_CMD | RECOVER_CMD  deriving (Eq)
cmdType "t"  = TEST_CMD
cmdType "e"  = EXTRACT_CMD
cmdType "x"  = EXTRACT_CMD
cmdType "cw" = EXTRACT_CMD
cmdType "l"  = LIST_CMD
cmdType "lb" = LIST_CMD
cmdType "lt" = LIST_CMD
cmdType "v"  = LIST_CMD
cmdType "r"  = RECOVER_CMD
cmdType  _   = ADD_CMD
{-# NOINLINE cmdType #-}

-- |������ ����������, ������������ � HEADER BLOCK
aARCHIVE_VERSION = make4byte 0 0 6 7

{-# NOINLINE aARC_VERSION_WITH_DATE #-}
{-# NOINLINE aARC_HEADER_WITH_DATE #-}
{-# NOINLINE aARC_HEADER #-}
{-# NOINLINE aARC_VERSION #-}
{-# NOINLINE aARC_AUTHOR #-}
{-# NOINLINE aARC_EMAIL #-}
{-# NOINLINE aARC_WEBSITE #-}
{-# NOINLINE aARC_LICENSE #-}
-- |������� ������������ ���������, ��������� � ������ ������
aARC_VERSION_WITH_DATE = aARC_VERSION                              -- aARC_VERSION ++ " ("++aARC_DATE++")"
aARC_HEADER_WITH_DATE  = aARC_HEADER                               -- aARC_HEADER  ++ " ("++aARC_DATE++")"
aARC_HEADER  = aARC_NAME++" "++aARC_VERSION++" "
aARC_VERSION = (if aFreeArc == "FreeArc" then "0.67" else "1.0") ++" ("++aARC_DATE++")"                            --  "0.666"
aARC_DATE    = "March 15 2014"
aARC_NAME    = aFreeArc
aARC_AUTHOR  = "Bulat Ziganshin"
aARC_EMAIL   = "Bulat.Ziganshin@gmail.com"
aARC_WEBSITE = "http://freearc.org"
aARC_LICENSE = ["0459 High-performance archiver", "0460 Free as well for commercial as for non-commercial use"]

{-# NOINLINE aHELP #-}
-- |HELP, ��������� ��� ������ ��������� ��� ����������
aHELP = aARC_HEADER++" "++aARC_WEBSITE++"  "++aARC_DATE++"\n"++
        joinWith ". " (map i18no aARC_LICENSE)++"\n"++
        "Usage: Arc command [options...] archive [files... @listfiles...]\n" ++
        joinWith "\n  " ("Commands:":commandsList) ++ "\nOptions:\n" ++ optionsHelp

-- |������� ����������� ������ ��� �����-����� ��� ���������� ������
data Grouping = GroupNone                   -- ������ ���� ��������
                                            -- ����������� ��:
              | GroupByExt                  --   ����������� ����������
              | GroupBySize      FileSize   --   ������������ ������ ����� ������
              | GroupByBlockSize MemSize    --   ������������� ������ ����� ������ (��� ������-��������������� ����������, ����� ��� BWT � ST)
              | GroupByNumber    FileCount  --   ���������� ������
              | GroupAll                    -- ��� ����� ������

-- |�������� ����� -d[f]: �� �������, ������� ������ �����, ������� ����� � ��������
data DelOptions = NO_DELETE | DEL_FILES | DEL_FILES_AND_DIRS  deriving (Eq)

-- |��� ����������� ��������
data OP_TYPE = COMPRESSION | DECOMPRESSION  deriving (Eq)


---------------------------------------------------------------------------------------------------
-- ��������, ������������ �� ��������� ------------------------------------------------------------
---------------------------------------------------------------------------------------------------

-- |����� ������ ������
aDEFAULT_COMPRESSOR = "4"

-- |����� ������ �������� ������
aDEFAULT_DIR_COMPRESSION = "lzma:mfbt4:d1m"

-- |������ �����-������ (���� �����-���� �� ����)
aDEFAULT_DATA_GROUPING  =  ""

-- |����������� ��� ���������
aDEFAULT_DIR_GROUPING  =  GroupByNumber (100*1000)

-- |�������� ����������
aDEFAULT_ENCRYPTION_ALGORITHM = "aes"

-- |���� � ��������� ������ �� ������� ����� �������������� ������ - ������������ ���, �.�. "*"
aDEFAULT_FILESPECS = [reANY_FILE]

-- |���������� �������� ������
aDEFAULT_ARC_EXTENSION = "."++aFreeArcInternalExt

-- |���������� SFX �������� ������
aDEFAULT_SFX_EXTENSION = ""

-- |���� ����������� �� ���������
aLANG_FILE = "arc.language.txt"

-- |���� ����������� ��� ������������� tooltips
aENGLISH_LANG_FILE = "arc.english.txt"

-- |���� � ��������� ������� ���������� ��� ������ ��� "-og"
aDEFAULT_GROUPS_FILE = "arc.groups"

-- |SFX-������, ������������ �� ���������, � ����������� �� ���� ������
default_sfx t | t==aFreeArcInternalExt = "freearc.sfx"
              | otherwise              = t++".sfx"

-- |����� ������������ (�������� �����, ������������ �� ���������)
aCONFIG_FILES = "arc*.ini"

-- |���������� �����, ���������� �����, ������������ �� ���������
aCONFIG_ENV_VAR = "FREEARC"

-- |������� ����������, ������������ ��� solid-������ (��� ���������� ������)
aDEFAULT_SOLID_SORT_ORDER = "gerpn"

-- |����� ����������, ��������� �� ����� - �� ��������� � ��� ������������� ����� "--display" ��� ���������.
-- �� ��������� �� ����� �� ��������� "cmo" - ���. �����, ����� ������ � ������������ ������
aDISPLAY_DEFAULT = "hanwrftske"
aDISPLAY_ALL     = "hoacmnwrfdtske"

-- ������ arc.ini
aCOMPRESSION_METHODS = "[Compression methods]"
aDEFAULT_OPTIONS     = "[Default options]"
aEXTERNAL_COMPRESSOR = "[External compressor:*]"

-- |�������� ����, ��� ��� - ��������� ������
isSectionHeading  =  beginWith "[" . trim

-- |���������� ����� ������ � ����������������� �����
cleanupSectionName  =  strLower . filter (not.isSpace)


----------------------------------------------------------------------------------------------------
---- ������������� ������ ��������� ������ ---------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- |�������� ����� - ������� ���, ������� ���, ���������� ��������
data Option = OPTION String String String  deriving Show

-- |��� ����� - �������� ����� ������� "-", ������� - ������� "--"
data OptType  =  SHORT | LONG deriving Show

-- |������� ��������� � �����: ���/�����������/�����������
data ParamType  =  ParamNo | ParamReq | ParamOpt deriving Show

-- |"�������" �����, ���������� �� � ������� ��� ������� ��������� ������ �����
optionsDict  =  concatMap compileOption optionsList
  where compileOption (OPTION short long description)  =  compile short ++ compile ('-':long)
          where -- �������� � ������ �������� ����� � ������ `name`, ���� ��� ��������
                compile name  =  case (name, paramName description) of
                    ("",  _      )  ->  []                                -- ��� ����� - ��� � ����� :)
                    ("-", _      )  ->  []                                -- ��� ����� - ��� � ����� :)
                    (_,   Nothing)  ->  [(name, long|||short, ParamNo )]  -- ����� ��� ���������
                    (_,   Just _ )  ->  [(name, long|||short, ParamReq)]  -- ����� � ����������

-- |�������� ����� ��� ������������.
optionsHelp  =  init$ unlines table
  where (ss,ls,ds)     = (unzip3 . map fmtOpt) optionsList
        table          = zipWith3 paste (sameLen ss) (sameLen ls) ds
        paste x y z    = "  " ++ x ++ "  " ++ y ++ "  " ++ z
        sameLen xs     = flushLeft ((maximum . map length) xs) xs
        flushLeft n    = map (left_justify n)
          -- ���������� ������ "�������� �����", "������� �����", � �� ��������
        fmtOpt (OPTION short long description)  =  (format short "" description, format ('-':long) "=" description, description)
          -- ���������� ������ ����� `name` � ������ ������� � �� ����� � ���������
        format name delim description  =  case (name, paramName description) of
                                            ("",   _         )  ->  ""
                                            ("-",  _         )  ->  ""
                                            ("--", _         )  ->  "--"
                                            (_,    Nothing   )  ->  "-"++name
                                            (_,    Just aWORD)  ->  "-"++name++delim++aWORD

-- |���������� ��� ��������� �����, �������� ��� �� ������ � ��������.
paramName descr =
  case filter (all isUpper) (words descr)
    of []      -> Nothing      -- �������� �� �������� UPPERCASED ����
       [aWORD] -> Just aWORD   -- �������� �������� UPPERCASED �����, ������������ �������� �����
       _       -> error$ "option description \""++descr++"\" contains more than one uppercased word"

-- |������ ��������� ������, ������������ ������ ����� � ������ "��������� ����������"
parseOptions []          _ options freeArgs  =  return (reverse options, reverse freeArgs)
parseOptions ("--":args) _ options freeArgs  =  return (reverse options, reverse freeArgs ++ args)

parseOptions (('-':option):args) option_checks options freeArgs = do
  let check (prefix, _, ParamNo)  =  (option==prefix)
      check (prefix, _, _)        =  (startFrom prefix option /= Nothing)
  let check2 (prefix, name, haveParam)  =  (lookup name option_checks `defaultVal` const True)  (tryToSkip "=" (tryToSkip prefix option))
  let accept (prefix, name, haveParam)  =  return (name, tryToSkip "=" (tryToSkip prefix option))
      unknown                           =  registerError$ CMDLINE_UNKNOWN_OPTION ('-':option)
      ambiguous variants                =  registerError$ CMDLINE_AMBIGUOUS_OPTION ('-':option) (map (("--"++).snd3) variants)      -- to do: "-" or "--" depending on short/long option
  newopt <- case (filter check2 $ filter check optionsDict) of
              [opt] -> accept opt  -- ������� �����
              []    -> unknown     -- ����������� �����.
              xs    -> -- ��� ��������������� � ������� ����� ��������� �� ������ ���������������� �����
                       case (filter ((`notElem` aLEAST_PRIORITY_OPTIONS) . snd3) xs) of
                         [opt] -> accept opt        -- ������� �����
                         []    -> ambiguous xs      -- ������������� �����, ������� ��� � ������ ������������
                         xs    -> -- �������� ����! :)
                                  case (filter ((`elem` aPREFFERED_OPTIONS++aSUPER_PREFFERED_OPTIONS) . snd3) xs) of
                                    [opt] -> accept opt        -- ������� �����
                                    []    -> ambiguous xs      -- ������������� �����, ������� ��� � ������ ������������
                                    xs    -> -- �������� ����! :)
                                             case (filter ((`elem` aSUPER_PREFFERED_OPTIONS) . snd3) xs) of
                                               [opt] -> accept opt        -- ������� �����
                                               []    -> ambiguous xs      -- ������������� �����, ������� ��� � ������ ������������
                                               xs    -> ambiguous xs      -- ������������� ������ ���� � ������ ������������!

  parseOptions args option_checks (newopt:options) freeArgs

parseOptions (arg:args) option_checks options freeArgs   =   parseOptions args option_checks options (arg:freeArgs)


-- |������� ������ �������� ����� � ��������� `flag`. ������ ������: findReqList opts "exclude"
findReqList ((name, param):flags) flag  | name==flag  =  param: findReqList flags flag
findReqList (_:flags) flag                            =  findReqList flags flag
findReqList [] flag                                   =  []

-- |������� �������� ����� � ��������� `flag`, ���� � ��� - �������� �� ��������� `deflt`
findReqArg options flag deflt  =  last (deflt : findReqList options flag)

-- |������� �������� ����� � �������������� ����������
findOptArg = findReqArg

-- |������� �������� ����� � ��������� `flag`, ���� � ��� - Nothing
findMaybeArg options flag  =  case findReqList options flag
                                of [] -> Nothing
                                   xs -> Just (last xs)

-- |������� True, ���� � ������ ����� ���� ����� � ��������� `flag`
findNoArg options flag  =  case findReqList options flag
                                of [] -> False
                                   _  -> True

-- |������� Just True, ���� � ������ ����� ���� ����� � ��������� `flag1`,
--          Just False, ���� � ������ ����� ���� ����� � ��������� `flag2`,
--          Nothing, ���� ��� �� ���, �� ������
findNoArgs options flag1 flag2  =  case filter (\(o,_) -> o==flag1||o==flag2) options
                                     of [] -> Nothing
                                        xs -> Just (fst (last xs) == flag1)

{-# NOINLINE optionsDict #-}
{-# NOINLINE optionsHelp #-}
{-# NOINLINE parseOptions #-}
{-# NOINLINE findReqList #-}
{-# NOINLINE findReqArg #-}
{-# NOINLINE findMaybeArg #-}
{-# NOINLINE findNoArg #-}
{-# NOINLINE findNoArgs #-}

----------------------------------------------------------------------------------------------------
---- ��������������� ����������� -------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- �������� ���� �� ���������� ��������� �� �������
opt `select` variants  =  words (split ',' variants !! opt)
-- �������� ���� �� ���������� ��������� �� �������
select1 prefix variants opt  =  words ((variants !! opt) .$unlessNull (prefix++))
-- ����������� ����� ��������� � ������ �����, �������������� ������ ����������� � � ������
cvt1 opt  =  map (opt++) . (||| [""]) . words . clear
-- �� �� �����, ������ ��� ����� ����������� ������ � ������, �� ������������ � "-"
cvt  opt  =  map (\w -> (w!~"-?*" &&& opt)++w) . (||| [""]) . words . clear
-- ������� ����������� ���� "*: " � ������ ������
clear     =  removeQuotes . trim . snd . splitCmt ""
-- |removeQuotes "text" ���������� ������ text, ��������� - ��� ���������
removeQuotes ('\x22':text) | endWith "\"" text  =  dropEnd 1 text
removeQuotes text                               =  text
-- |��������� �������� �� ��������+�����
splitCmt "" text@('\x22':ws) | endWith "\"" ws  =  ("", text)   -- "text" ���������� ������ "text" ��� ��������
splitCmt xs ""           = ("", reverse xs)
splitCmt xs ":"          = (reverse xs, "")
splitCmt xs (':':' ':ws) = (reverse xs, ws)
splitCmt xs (w:ws)       = splitCmt (w:xs) ws


----------------------------------------------------------------------------------------------------
---- System information ----------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- |Number of physical processors/cores in the system. Determines number of heavy-computations thread runned
foreign import ccall unsafe "Environment.h GetProcessorsCount"
  getProcessorsCount :: CInt

-- |Size of physical computer memory in bytes
foreign import ccall unsafe "Environment.h GetPhysicalMemory"
  getPhysicalMemory :: Word64

-- |Size of maximum memory block we can allocate in bytes
foreign import ccall unsafe "Environment.h GetMaxBlockToAlloc"
  getMaxBlockToAlloc :: IO CUInt

-- |Size of physical computer memory that is currently unused
foreign import ccall unsafe "Environment.h GetAvailablePhysicalMemory"
  getAvailablePhysicalMemory :: IO Word64

-- |Prints detailed stats about memory available
foreign import ccall safe "Environment.h TestMalloc"
  testMalloc :: IO ()
