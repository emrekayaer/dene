#CROSS_COMPILE?=arm-arago-linux-gnueabi-
CROSS_COMPILE?=""

LIBDIR_APP_LOADER?=../../app_loader/lib
INCDIR_APP_LOADER?=../../app_loader/include
BINDIR?=../bin
PASM?=../../utils/pasm
ASSEM_FILE?=iic_ioexp.p
BIN_FILE?=iic_ioexp.bin

CFLAGS+= -Wall -I$(INCDIR_APP_LOADER) -D__DEBUG -O2 -mtune=cortex-a8 -march=armv7-a
LDFLAGS+=-L$(LIBDIR_APP_LOADER) -lprussdrv -lpthread
OBJDIR=obj
TARGET=$(BINDIR)/iic_ioexp
TARGET_BIN=$(BINDIR)/$(BIN_FILE)

_DEPS = 
DEPS = $(patsubst %,$(INCDIR_APP_LOADER)/%,$(_DEPS))

_OBJ = iic_ioexp.o
OBJ = $(patsubst %,$(OBJDIR)/%,$(_OBJ))


$(OBJDIR)/%.o: %.c $(DEPS)
	@mkdir -p obj
	$(CROSS_COMPILE)gcc $(CFLAGS) -c -o $@ $< 

$(TARGET): $(OBJ)
	$(CROSS_COMPILE)gcc $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(TARGET_BIN): ${ASSEM_FILE}
	${PASM} -b ${ASSEM_FILE}
	mv *.bin ${BINDIR_FW}

.PHONY: clean

clean:
	rm -rf $(OBJDIR)/ *~  $(INCDIR_APP_LOADER)/*~  $(TARGET)
	rm -fr ${BINDIR_FW}/${BIN_FILE}

