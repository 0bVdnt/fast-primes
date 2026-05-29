LLL ?= llvm-link
OPT ?= opt
LLC ?= llc
LLD ?= ld.lld

OPTFLAGS = -O3

SRC_DIR   = src
BUILD_DIR = build
BIN_DIR   = bin

TARGET    = $(BIN_DIR)/fast-primes
LINKED_BC = $(BUILD_DIR)/fast-primes.bc
OPT_BC    = $(BUILD_DIR)/fast-primes.opt.bc
OBJ_FILE  = $(BUILD_DIR)/fast-primes.o

SYS_SRCS    = $(wildcard $(SRC_DIR)/sys/*.ll)
MATH_SRCS   = $(wildcard $(SRC_DIR)/math/*.ll)
LEHMER_SRCS = $(wildcard $(SRC_DIR)/lehmer/*.ll)
MAIN_SRC    = $(SRC_DIR)/main.ll

ALL_SRCS = $(MAIN_SRC) $(SYS_SRCS) $(MATH_SRCS) $(LEHMER_SRCS)

# Optional architecture flag
MARCH_FLAG ?= -march=x86-64

.PHONY: all native generic clean prep

# Default build
all: generic

# Build with specified -march (default: x86-64)
native: prep $(TARGET)

# Build without any -march
generic: MARCH_FLAG=
generic: prep $(TARGET)

prep:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(BIN_DIR)

# Link all IR modules into a single bitcode file
$(LINKED_BC): $(ALL_SRCS)
	@echo "[LINK] Aggregating IR modules."
	$(LLL) $^ -o $@

# Run the middle-end optimizer
$(OPT_BC): $(LINKED_BC)
	@echo "[OPT]  Running optimization passes."
	$(OPT) $(OPTFLAGS) $< -o $@

# Lower to target-specific machine object
$(OBJ_FILE): $(OPT_BC)
	@echo "[LLC]  Lowering to machine object."
	$(LLC) $(OPTFLAGS) $(MARCH_FLAG) -filetype=obj $< -o $@

# Link into final executable
$(TARGET): $(OBJ_FILE)
	@echo "[LLD]  Linking executable."
	$(LLD) $< -o $@
	@echo "[DONE] Built target: $@"

clean:
	@echo "[CLEAN] Removing build artifacts."
	rm -rf $(BUILD_DIR)
	rm -rf $(BIN_DIR)
