################################################################################

NAME = 7800GDFeatures
SRC = test.s
WAV = 0.wav
BUP = 0.bup

################################################################################

SIGN = 7800sign
HEADER = 7800header
ASM = dasm
ASMFLAGS = -I$(A7800_DEVKIT)/includes -f3
OUTDIR = out
ADPCM = ./7800GDAudioEncode.exe

################################################################################

$(OUTDIR)/$(NAME).a78: $(OUTDIR)/$(NAME).bin
	$(HEADER) -f settings.txt $(OUTDIR)/$(NAME).bin

$(OUTDIR)/$(NAME).bin: makefile $(SRC) $(OUTDIR)/$(NAME)/$(BUP) | $(OUTDIR) $(OUTDIR)/$(NAME)
	$(ASM) $(SRC) $(ASMFLAGS) -L$(OUTDIR)/$(NAME).lst -o$(OUTDIR)/$(NAME).bin
	$(SIGN) -w $(OUTDIR)/$(NAME).bin

$(OUTDIR)/$(NAME)/$(BUP): $(WAV)
	$(ADPCM) $(WAV) -o $(OUTDIR)/$(NAME) -loop

$(OUTDIR):
	mkdir -p $(OUTDIR)

$(OUTDIR)/$(NAME):
	mkdir -p $(OUTDIR)/$(NAME)

clean:
	rm -f -r $(OUTDIR)
