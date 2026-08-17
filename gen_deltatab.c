#include <stdio.h>
#include <stdint.h>

int main() {
    printf("static const uint16_t deltaTable[128][2] = {\n");
    
    for (int v = 0; v < 128; v++) {
        int r_delta = ((v >> 5) & 0x3) - 2;
        int g_delta = ((v >> 2) & 0x7) - 4;
        int b_delta = (v & 0x3) - 2;
        
        uint16_t add = 0, sub = 0;
        
        // Separate positive deltas (to add) from negative (to subtract)
        if (r_delta >= 0) {
            add |= (uint16_t)(r_delta << 11);
        } else {
            sub |= (uint16_t)((-r_delta) << 11);
        }
        
        if (g_delta >= 0) {
            add |= (uint16_t)(g_delta << 5);
        } else {
            sub |= (uint16_t)((-g_delta) << 5);
        }
        
        if (b_delta >= 0) {
            add |= (uint16_t)(b_delta);
        } else {
            sub |= (uint16_t)((-b_delta));
        }
        
        printf("    {0x%04X, 0x%04X}%s\n", add, sub, (v < 127) ? "," : "");
    }
    
    printf("};\n");
    return 0;
}