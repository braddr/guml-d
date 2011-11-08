/* local.h */
/* contains all relevant local settings */

#if 0
#ifdef SITE_DREYFUS
#  define ACCTROOT  "/home/dreyfus/www2"
#  define GUMLROOT  ACCTROOT "/"
#  define DATAROOT  GUMLROOT
#  define GUMLHEADERDIR "headers"
#  define GUMLHEADERROOT ACCTROOT "/content/toolkits/calcs/" GUMLHEADERDIR "/" 
#  define EXECGUML  ACCTROOT "/cgi-bin/guml"
#  define LOGFILE   ACCTROOT "/guml.log"
#  define FILE_WRITE_DIR GUMLROOT
#endif

#ifdef SITE_VISA_EXPO
#  define IWVPATH        "/l/iw/bin/iwvpath"
#  define NEED_SQL_ENVIRONMENT
#  define ARG_HANDLE_BOTH_FORMATS
#ifdef DEVELOPMENT
#  define ACCTROOT       "/tmp"
#  define DB_DB          "visa"
#  define DB_ROOT        "/pkgs/informix7.13"
#  define DB_HOST        "excalibur_tcp"
#  define USE_STANDARD_DIR_LOCATIONS
#else
#  define ACCTROOT       "/ans/content/visa/expo"
#  define DB_DB          "visadb1"
#  define DB_ROOT        "/ans/pkg/informix"
#  define DB_HOST        "visa1_tli"
#  define LOGFILE        "/tmp/guml_logfile"
#  define DATAROOT       ACCTROOT "/data/"
#  define GUMLROOT       ACCTROOT "/web/"
#  define EXECGUML       ACCTROOT "/web/cgi-bin/bestguml"
#endif
#  define USE_STANDARD_FILE_WRITE_DIR
#endif

#ifdef SITE_COLD
#  define ACCTROOT "/home/brad/websites/cold"
#  define USE_STANDARD_FILE_WRITE_DIR
#  define USE_STANDARD_DIR_LOCATIONS
#  define ARG_HANDLE_USE_ONLY_GET_FORMAT
#  define DB_HOST        "lakeo.puremagic.com"
#  define DB_DB          "webboard"
#  define DB_USERID      "braddr"
#  define DB_PASSWORD    "adg1Qet"
#endif

#ifdef SITE_TESTING
#  define ACCTROOT "/home/www-data/root"
#  define DB_HOST        "burnboy_shm"
#  define DB_DB          "website"
#  define DB_ROOT        "/home/informix"
#  define LOGFILE        "/tmp/guml_logfile"
#  define DATAROOT       ACCTROOT "/"
#  define GUMLROOT       ACCTROOT "/"
#  define EXECGUML       ACCTROOT "/cgi-bin/actualbestguml"
#  define USE_STANDARD_FILE_WRITE_DIR
#  define NEED_SQL_ENVIRONMENT
#  define ARG_HANDLE_USE_ONLY_GET_FORMAT
#endif

#ifdef SITE_GUML_COM
#  define ACCTROOT	"/home/www-data/www.guml.org/root"
#  define DATAROOT       ACCTROOT "/"
#  define GUMLROOT       ACCTROOT "/"
#  define USE_STANDARD_FILE_WRITE_DIR
#  define ARG_HANDLE_USE_ONLY_GET_FORMAT
#  define EXECGUML       ACCTROOT "/cgi-bin/actualbestguml"
#  define LOGFILE        "/tmp/guml_log"
#  define DB_ROOT        "/home/informix"
#  define DB_HOST        "test_shm"
#endif

#ifdef SITE_INTRADEV
#  define ACCTROOT       "/disk/palace/Departments/web"
#  define USE_STANDARD_DIR_LOCATIONS
#  define USE_STANDARD_FILE_WRITE_DIR
#endif

#ifdef SITE_SHOCKSTER
#  define ACCTROOT       "/disk/tweedledum/users/clients/shockster"
#  define USE_STANDARD_DIR_LOCATIONS
#  define USE_STANDARD_FILE_WRITE_DIR
#endif

#ifdef SITE_FOUNDERS
#  define ACCTROOT       "/inetpub/newguml"
#  define LOGFILE        ACCTROOT "/guml_logfile"
#  define DATAROOT       ACCTROOT "/data/data/"
#  define GUMLROOT       ACCTROOT "/data/docs/"
#  define EXECGUML       ACCTROOT "/unused"
#  define DB_ROOT        "/mssql"
#  define DB_HOST        ""
#  define DB_DB          "flanders"
#  define DB_USERID      "wingnut"
#  define DB_PASSWORD    "l0ckst3p"
#  define DB_APPNAME     "puml.exe"
#  define USE_STANDARD_FILE_WRITE_DIR
#endif

#ifdef SITE_CHEVY
#  define NEED_SQL_ENVIRONMENT
#  define ACCTROOT       "/home/chevychase"
#  define DB_ROOT        "/pkgs/oracle7/product/732"
#  define DB_HOST        "test"
#  define DB_DB          "MOLSON"
#  define DB_USERID      "chevy"
#  define DB_PASSWORD    "chase"
#  define ORAADMIN       DB_ROOT "/network/admin"
#  define USE_STANDARD_DIR_LOCATIONS
#  define USE_STANDARD_FILE_WRITE_DIR
#endif

#ifdef SITE_MOLSON
#  define NEED_SQL_ENVIRONMENT
#  define ACCTROOT       "/home/molson"
#  define DB_ROOT        "/pkgs/oracle7/product/732"
#  define DB_HOST        "test"
#  define DB_DB          "MOLSON"
#  define DB_USERID      "molson"
#  define DB_PASSWORD    "carg0"
#  define ORAADMIN       DB_ROOT "/network/admin"
#  define USE_STANDARD_DIR_LOCATIONS
#  define FILE_WRITE_DIR "/home/molson/data"
#endif

#ifdef SITE_RANKIT
#  define NEED_SQL_ENVIRONMENT
#  define ACCTROOT       "/disk/free/users/visa/rankit"
#  define DB_DB          "visa"
#  define DB_ROOT        "/pkgs/informix7.13"
#  define DB_HOST        "excalibur_tcp"
#  define USE_STANDARD_DIR_LOCATIONS
#  define USE_STANDARD_FILE_WRITE_DIR
#endif

#ifdef SITE_CYBERSIGHT
#  define ACCTROOT       "/home/www/work-http"
#  define LOGFILE        "/tmp/guml_logfile"
#  define DATAROOT       ACCTROOT "/data/data/"
#  define GUMLROOT       ACCTROOT "/data/docs/"
#  define EXECGUML       ACCTROOT "/home/www/lib-http/cgi-bin/actualbestguml"
#  define DB_ROOT        "/space/sybase"
#  define DB_HOST        "SBOARD1"
#  define DB_DB	         "cybersight"
#  define DB_USERID      "cybersight"
#  define DB_PASSWORD    "beatme!!"
#  define DB_APPNAME     "bestguml"
#  define USE_STANDARD_FILE_WRITE_DIR
#endif

#ifdef SITE_COLORIZE
#  define NEED_SQL_ENVIRONMENT
#  define ACCTROOT       "/home/colorize"
#  define DB_ROOT        "/pkgs/oracle7/product/732"
#  define DB_HOST        "test"
#  define DB_DB          "MOLSON"
#  define DB_USERID      "colorize"
#  define DB_PASSWORD    "c0l0r"
#  define ORAADMIN       DB_ROOT "/network/admin"
#  define USE_STANDARD_DIR_LOCATIONS
#  define USE_STANDARD_FILE_WRITE_DIR
#endif

#ifdef SITE_TEACH
#ifdef DEVELOPMENT
#  define ACCTROOT  "/home/httpd/teach"
#  define DB_PASSWORD    ""
#else
#  define ACCTROOT  "/usr/local/apache/sites/ttt"
#  define DB_PASSWORD    "ttt"
#endif
#  define GUMLROOT       ACCTROOT "/"
#  define DATAROOT       ACCTROOT "/"
#  define EXECGUML       ACCTROOT "/cgi-bin/actualbestguml"
#  define DB_HOST        "localhost"
#  define DB_DB          "ttt"
#  define DB_USERID      "ttt"
#  define DB_SOCKET      "/tmp/msql.sock|"
#  define LOGFILE        ACCTROOT "/logs/guml_logfile"
#  define USE_STANDARD_FILE_WRITE_DIR
#endif

#ifdef SITE_DOLE
#  define NEED_SQL_ENVIRONMENT
#ifdef DEVELOPMENT
#  define ACCTROOT       "/home/dole/www"
#  define DB_ROOT        "/opt2/oracle8/OraHome1"
#  define DB_HOST        "test"
#  define DB_DB          "DOLE"
#else
#  define ACCTROOT       "/home/dole/www"
#  define DB_ROOT        "/local/home/oracle/app/oracle/product/8.1.5"
#  define DB_HOST        "TEST"
#  define DB_DB          "TEST"
#endif
#  define GUMLROOT       ACCTROOT "/"
#  define DATAROOT       ACCTROOT "/"
#  define EXECGUML       ACCTROOT "/cgi-bin/actualbestguml"
#  define DB_USERID      "dole"
#  define DB_PASSWORD    "d0l3"
#  define ORAADMIN       DB_ROOT "/network/admin"
#  define LOGFILE        "/tmp/guml_logfile"
#  define USE_STANDARD_FILE_WRITE_DIR
#endif

#ifdef SITE_CRUNCH
#  define NEED_SQL_ENVIRONMENT
#  define ACCTROOT       "/home/quaker/wwwdev"
#  define GUMLROOT       ACCTROOT "/"
#  define DATAROOT       ACCTROOT "/"
#  define EXECGUML       ACCTROOT "/cgi-bin/actualbestguml"
#  define DB_HOST        "localhost"
#  define DB_DB          "nobody"
#  define DB_USERID      "nobody"
#  define DB_SOCKET      "/tmp/quaker_msql.sock|"
#  define USE_STANDARD_FILE_WRITE_DIR
#endif

#endif

#define USE_STANDARD_DIR_LOCATIONS
#define USE_STANDARD_FILE_WRITE_DIR
#define ARG_HANDLE_USE_ONLY_GET_FORMAT

#ifdef USE_MYSQL
#define DB_HOST		"localhost"
#define DB_DB		"dwebsite"
#define DB_USERID	"dwebsite"
#define DB_PASSWORD	"fn0rd3"
#endif

#ifdef USE_STANDARD_FILE_WRITE_DIR
#  define FILE_WRITE_DIR "/tmp"
#endif

#ifdef USE_STANDARD_DIR_LOCATIONS
#  define LOGFILE        "/tmp/guml_logfile"
#endif

