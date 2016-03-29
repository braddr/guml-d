# define for fastcgi, comment out otherwise
FASTCGI = yes

# define for building optimized
#OPTIMIZE = yes

# define for various debugging flags
#DEBUG_BUILD = yes
#DEBUG_ENV = yes
#DEBUG_SQL = yes

# MODE = DEVELOPMENT
MODE = PRODUCTION

DB = MYSQL

OS = LINUX

#=======================================

# OS Specific Defines

ifeq (${OS},LINUX)
OSDEFINES = 
endif

DEFINES += -D${MODE}
ifdef OSDEFINES
DEFINES += ${OSDEFINES}
endif

ifeq (${DB},MYSQL)
DB_OBJS = mysql.o
DB_LIBS = -L/usr/lib64/mysql56 -lmysqlclient
endif

OTHER_LIBS = -lm

ifdef DEBUG_BUILD
DFLAGS += -gc
endif
ifdef DEBUG_ENV
DFLAGS += -version=DEBUG_ENV
endif
ifdef DEBUG_SQL
DFLAGS += -version=DEBUG_SQL
endif
ifdef FASTCGI
DFLAGS += -version=FASTCGI
endif
ifdef OPTIMIZE
DFLAGS += -O
endif

O_FILES = setup.o engine.o commands.o env_ops.o dir_ops.o file_ops.o math_ops.o \
          string_ops.o email.o hash_table.o prims.o www.o calculator.o string_utils.o \
          $(DB_OBJS)

LIBS = ${OS_LIBS} ${DB_LIBS} ${OTHER_LIBS}
ifdef FASTCGI
LIBS += -lfcgi
endif

DMD=dmd

.SUFFIXES: .d
.d.o:
	$(DMD) -c -g -w $(DFLAGS) $<

all: dbestguml

install: all
	echo "You need to copy the files yourself for now.."

clean:
	rm -f *.o dbestguml

dbestguml: bestguml.o $(O_FILES)
	$(DMD) -ofdbestguml bestguml.o $(O_FILES) $(addprefix -L,$(LIBS))

bestguml.o: bestguml.d

setup.o: setup.d

commands.o: commands.d

dir_ops.o: dir_ops.d

engine.o: engine.d

env_ops.o: env_ops.d

file_ops.o: file_ops.d

hash_table.o: hash_table.d

string_ops.o: string_ops.d

math_ops.o: math_ops.d

prims.o: prims.d

www.o: www.d

email.o: email.d

calculator.o: calculator.d

string_utils.o: string_utils.d

ifeq (${DB},MYSQL)
mysql.o: mysql.d
endif

# End.
