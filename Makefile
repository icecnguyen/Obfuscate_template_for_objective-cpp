CXX = clang++
CXXFLAGS = -std=c++14 -I./include -fobjc-arc -arch arm64

SOURCES = src/ObjCObfuscation.mm src/AntiDebug.mm src/AntiDump.mm src/AntiHook.mm src/AntiDecryption.mm src/AntiEnvironment.mm src/AntiTamper.mm
OBJECTS = $(SOURCES:.mm=.o)

all: obfuscator_static.a

obfuscator_static.a: $(OBJECTS)
	ar rcs $@ $(OBJECTS)

%.o: %.mm
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJECTS) obfuscator_static.a