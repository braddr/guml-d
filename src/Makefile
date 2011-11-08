# Makefile for bestguml

# define for tuxedo, comment out otherwise
# TUXEDO = yes
 
# define for fastcgi, comment out otherwise
# FASTCGI = yes

# define for purify compilation
# PURIFY = yes

#define for quantify compilation
# QUANTIFY = yes

#define for using gprof
# GPROF = yes

#define for building optimized
# OPTIMIZE = yes

#define for various debugging flags
DEBUG_BUILD = yes
DEBUG_ENV = no
DEBUG_SQL = yes

# MODE = DEVELOPMENT
MODE = PRODUCTION

# DB = SYBASE
# DB = ORACLE
# ORACLEV = 723
# ORACLEV = 734
# ORACLEV = 8
# DB = KUBL
# DB = INFORMIX
DB = MYSQL

# SITE = VISA_EXPO
# SITE = TESTING
# SITE = MOLSON
# SITE = COLORIZE
# SITE = RANKIT
# SITE = CYBERSIGHT
# SITE = CHEVY
# SITE = SHOCKSTER
# SITE = INTRADEV
# SITE = COLD
# SITE = TEACH
# SITE = DOLE
# SITE = DREYFUS
# SITE = GUML_COM

# OS = SOLARIS_251
# OS = SOLARIS_26
OS = LINUX
# OS = AIX

#=======================================

# OS Specific Defines

ifeq (${OS},SOLARIS_251)
OSDEFINES = -DNEED_CRYPT -DNEED_RANDOM
endif

ifeq (${OS},SOLARIS_26)
OSDEFINES = -DNEED_CRYPT
endif

ifeq (${OS},LINUX)
OSDEFINES = 
endif

ifeq (${OS},AIX)
OSDEFINES =
endif

# Site Specific Stuff

ifeq (${SITE},MOLSON)
OS_LIBS = -lcrypt
DEFINES += -DUSE_FILE_HANDLE_OPS
endif

ifeq (${SITE},TESTING)
DEFINES += -DUSE_FILE_HANDLE_OPS -DBRADDR_TESTING
endif

ifdef TUXEDO
.EXPORT_ALL_VARIABLES:
ROOTDIR = /pkgs/guml/tuxedo/tux
endif
 
DEFINES += -D${MODE}
ifdef OSDEFINES
DEFINES += ${OSDEFINES}
endif

ifeq (${DB},SYBASE)
SYBASE     = /space/sybase
DB_CFLAGS  = -DUSE_SYBASE -I$(SYBASE)/include
DB_LIBS    = -L$(SYBASE)/lib -lsybdb -lsocket
DB_OBJS    = sybase_db.o
endif

ifeq (${DB},ORACLE)
DB_OBJS     = oracle.o
DB_CFLAGS   = -DUSE_ORACLE -I$(ORACLE_HOME)/rdbms/demo
ifeq (${ORACLEV},723)
ORACLE_HOME = /pkgs/oracle7/product/732
DB_LIBS     = -L$(ORACLE_HOME)/lib $(ORACLE_HOME)/lib/libclient.a -lsqlnet \
                -lncr -lsqlnet -lclient -lcommon -lgeneric -lsqlnet -lncr \
                -lsqlnet -lclient -lcommon -lgeneric -lepc -lnlsrtl3 -lc3v6 \
                -lcore3 -lnlsrtl3 -lcore3 -lnlsrtl3 -lsocket -lnsl -lm -ldl \
                -lposix4 -lsunmath -lm -lcore3 -lsocket -lnsl -lm -ldl \
                -lposix4 -lsunmath -lc -lm
else
  ifeq (${ORACLEV},734)
ORACLE_HOME = /usr/local/oracle/app/oracle/product/7.3.4
DB_LIBS     = -L$(ORACLE_HOME)/lib $(ORACLE_HOME)/lib/libclient.a -lsqlnet \
                -lncr -lsqlnet -lclient -lcommon -lgeneric -lsqlnet -lncr \
                -lsqlnet -lclient -lcommon -lgeneric -lepc -lnlsrtl3 -lc3v6 \
                -lcore3 -lnlsrtl3 -lcore3 -lnlsrtl3 -lsocket -lnsl -lm -ldl \
                -lposix4 -lm -lcore3 -lsocket -lnsl -lm -ldl -lposix4
  else
ORACLE_HOME = /opt2/oracle8/OraHome1
# this is why we love oracle:
DB_LIBS     = -L${ORACLE_HOME}/lib -L${ORACLE_HOME}/rdbms/lib \
                ${ORACLE_HOME}/rdbms/lib/ssdbaed.o \
                ${ORACLE_HOME}/rdbms/lib/kpudfo.o \
                ${ORACLE_HOME}/lib/naeet.o ${ORACLE_HOME}/lib/nautab.o \
                ${ORACLE_HOME}/lib/naect.o ${ORACLE_HOME}/lib/naedhs.o \
                -lnbeq8 -lnhost8 -ln8 -lncrypt8 -lnoss8 -lnidx8 -ln8 \
                -lncrypt8 -lnus8 -ln8 -lncrypt8 -lnoss8 -lnk58 -ln8 \
                -lncrypt8 -lnldap8 -lldapclnt8 -lnsslb8 -lnoss8 -ln8 \
                -lncrypt8 -lnoss8 -ln8 -lncrypt8 -lnoname8 -ln8 -lncrypt8 \
                -lnoss8 -lnsid8 -ln8 -lncrypt8 -lntcp8 -lntcps8 -lnsslb8 \
                -lntcp8 -lntns8 -ln8 -lnl8 -lnro8 -lnbeq8 -lnhost8 -ln8 \
                -lncrypt8 -lnoss8 -lnidx8 -ln8 -lncrypt8 -lnus8 -ln8 \
                -lncrypt8 -lnoss8 -lnk58 -ln8 -lncrypt8 -lnldap8 -lldapclnt8 \
                -lnsslb8 -lnoss8 -ln8 -lncrypt8 -lnoss8 -ln8 -lncrypt8 \
                -lnoname8 -ln8 -lncrypt8 -lnoss8 -lnsid8 -ln8 -lncrypt8 \
                -lntcp8 -lntcps8 -lnsslb8 -lntcp8 -lntns8 -ln8 -lnl8 \
                -lclient8 -lvsn8 -lcommon8 -lskgxp8 -lgeneric8 -lmm -lnls8 \
                -lcore8 -lnls8 -lcore8 -lnls8 -lnbeq8 -lnhost8 -ln8 \
                -lncrypt8 -lnoss8 -lnidx8 -ln8 -lncrypt8 -lnus8 -ln8 \
                -lncrypt8 -lnoss8 -lnk58 -ln8 -lncrypt8 -lnldap8 \
                -lldapclnt8 -lnsslb8 -lnoss8 -ln8 -lncrypt8 -lnoss8 -ln8 \
                -lncrypt8 -lnoname8 -ln8 -lncrypt8 -lnoss8 -lnsid8 -ln8 \
                -lncrypt8 -lntcp8 -lntcps8 -lnsslb8 -lntcp8 -lntns8 -ln8 \
                -lnl8 -lnro8 -lnbeq8 -lnhost8 -ln8 -lncrypt8 -lnoss8 \
                -lnidx8 -ln8 -lncrypt8 -lnus8 -ln8 -lncrypt8 -lnoss8 \
                -lnk58 -ln8 -lncrypt8 -lnldap8 -lldapclnt8 -lnsslb8 \
                -lnoss8 -ln8 -lncrypt8 -lnoss8 -ln8 -lncrypt8 -lnoname8 \
                -ln8 -lncrypt8 -lnoss8 -lnsid8 -ln8 -lncrypt8 -lntcp8 \
                -lntcps8 -lnsslb8 -lntcp8 -lntns8 -ln8 -lnl8 -lclient8 \
                -lvsn8 -lcommon8 -lskgxp8 -lgeneric8 -ltrace8 -lnls8 \
                -lcore8 -lnls8 -lcore8 -lnls8 -lclient8 -lvsn8 -lcommon8 \
                -lskgxp8 -lgeneric8 -lnls8 -lcore8 -lnls8 -lcore8 -lnls8 \
                -lnsl -lsocket -lgen -ldl -lsched -lc -laio -lposix4 \
                -lkstat -lm -lthread
  endif
endif
endif 

ifeq (${DB},KUBL)
DB_OBJS   = kubl.o
KUBL_HOME = /home/www-data/kubl
DB_CFLAGS = -DUSE_KUBL -DUNIX -I$(KUBL_HOME)/include 
DB_LIBS   = -L$(KUBL_HOME)/bin  -lwic -ldksrv -ldkses
endif

ifeq (${DB},INFORMIX)
#INFORMIXDIR = /pkgs/informix7.13
INFORMIXDIR = /home/informix
ESQLFLAGS   = -I$(INFORMIXDIR)/incl/esql -L$(INFORMIXDIR)/lib/esql
ESQL        = $(INFORMIXDIR)/bin/esql
DB_CFLAGS   = -DUSE_INFORMIX -I$(INFORMIXDIR)/incl/esql
DB_OBJS     = informix.o
FINAL_CC    = $(ESQL)
.SUFFIXES: .ec
.ec.o:
	$(ESQL) -c $(CFLAGS) $<
	rm -f $*.c
endif

ifeq (${DB},MYSQL)
DB_OBJS = mysql.o
DB_CFLAGS  = -DUSE_MYSQL
DB_LIBS    = -lmysqlclient
ifneq (${OS},LINUX)
    DB_LIBS += -lsocket
endif
endif

ifndef FINAL_CC
FINAL_CC = ${CC}
endif

OTHER_LIBS = -lm

CC = gcc
ifdef PURIFY
CC := purify ${CC}
endif

ifdef QUANTIFY
CC := quantify ${CC}
endif

CFLAGS = $(DEFINES) $(DB_CFLAGS) -std=c99 -Werror -D_XOPEN_SOURCE=500
ifdef GPROF
CFLAGS += -pg
endif
ifdef DEBUG_BUILD
CFLAGS += -Wall -g
endif
ifdef DEBUG_ENV
CFLAGS += -DDEBUG_ENV
endif
ifdef DEBUG_SQL
CFLAGS += -DDEBUG_SQL
endif
ifdef FASTCGI
CFLAGS += -DFASTCGI
endif
ifdef TUXEDO
CFLAGS += -DTUXEDO -I$(ROOTDIR)/../tpmsg -I$(ROOTDIR)/include -I$(ROOTDIR)/../libcsrv
endif
ifdef OPTIMIZE
CFLAGS += -O
ifeq (${OS},LINUX)
CFLAGS += -fomit-frame-pointer
endif
endif

CXXFLAGS = ${CFLAGS}

O_FILES = setup.o engine.o commands.o env_ops.o dir_ops.o file_ops.o math_ops.o \
          string_ops.o email.o hash_table.o prims.o www.o calculator.o string_utils.o \
          site_specific_ops.o filehandle_ops.o $(DB_OBJS)
ifdef TUXEDO
O_FILES += tuxedo.o
endif

LIBS = ${OS_LIBS} ${DB_LIBS} ${OTHER_LIBS}
ifdef FASTCGI
LIBS += -lfcgi
ifeq (${OS},SOLARIS_26)
LIBS += -lsocket -lnsl
endif
endif
ifdef TUXEDO
LIBS += -L$(ROOTDIR)/../lib -lcsrv -L$(ROOTDIR)/../tpmsg -ltpmsg
endif

.SUFFIXES: .d
.d.o:
	dmd -c -gc $<

all: test_hash bestguml

install: all
	echo "You need to copy the files yourself for now.."

clean:
	rm -f *.o bestguml stub test_hash

test_hash: test_hash.o hash_table.o
	$(CC) $(CFLAGS) -o test_hash test_hash.o hash_table.o

bestguml: bestguml.o $(O_FILES)
	dmd -ofbestguml bestguml.o $(O_FILES) $(addprefix -L,$(LIBS))

#stub: stub.o
#	${CC} $(CFLAGS) -o stub stub.o

stub.o: stub.c local.h

bestguml.o: bestguml.d global.h local.h

setup.o: setup.d global.h local.h

test_hash.o: test_hash.c global.h

commands.o: commands.c global.h local.h

engine.o: engine.d global.h local.h

env.o: env.c global.h local.h

file_ops.o: file_ops.c global.h local.h

filehandle_ops.o: filehandle_ops.c global.h local.h

string_ops.o: string_ops.c global.h local.h

math_ops.o: math_ops.c global.h local.h

prims.o: prims.c global.h local.h

www.o: www.c global.h

email.o: email.c global.h local.h

calculator.o: calculator.c global.h local.h

site_specific_ops.o: site_specific_ops.c global.h local.h

tuxedo.o: tuxedo.cc global.h local.h

ifeq (${DB},SYBASE)
sybase_db.o: sybase_db.c global.h local.h
endif

ifeq (${DB},ORACLE)
oracle.o: oracle.c global.h local.h
endif

ifeq (${DB},KUBL)
kubl.o: kubl.c global.h local.h
endif

ifeq (${DB},INFORMIX)
informix.o: informix.ec global.h local.h
endif

ifeq (${DB},MYSQL)
mysql.o: mysql.c global.h local.h
endif

# End.
