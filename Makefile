
MAIN_NAME = main
PROJECT_NAME = snake

all:
	rgbasm -o $(MAIN_NAME).o $(MAIN_NAME).asm
	rgblink -o $(PROJECT_NAME).gb $(MAIN_NAME).o
	rgbfix -v -p 0 $(PROJECT_NAME).gb

clean:
	rm -f *.gb *.o