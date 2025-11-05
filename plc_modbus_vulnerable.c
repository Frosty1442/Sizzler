/*
 * Simplified PLC Modbus Handler - Contains CVE-2023-43184
 *
 * This simulates the OpenPLC Modbus slave device attribute handling
 * that contains a buffer overflow vulnerability.
 *
 * CVE-2023-43184: Buffer overflow in OpenPLC runtime via Modbus slave attributes
 * Impact: Remote code execution, privilege escalation, DoS
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#define MAX_DEVICE_NAME 256
#define BUFFER_SIZE 1024

// Simulated PLC device structure
typedef struct {
    char device_name[MAX_DEVICE_NAME];
    uint16_t device_id;
    uint32_t device_addr;
    char buffer[BUFFER_SIZE];
} modbus_device_t;

// Global device (simulates PLC runtime state)
modbus_device_t plc_device;

/*
 * VULNERABLE FUNCTION - CVE-2023-43184
 *
 * This function processes Modbus slave device attributes.
 * It reads input and copies it to a fixed-size buffer without
 * proper bounds checking.
 */
void process_modbus_attribute(FILE* input) {
    char attribute_buffer[1024];
    char temp_buffer[2048];  // Temporary buffer for processing

    printf("[PLC] Reading Modbus device attribute...\n");

    // Read attribute from input (simulates Modbus TCP frame)
    if (fgets(attribute_buffer, sizeof(attribute_buffer), input) == NULL) {
        return;
    }

    // Remove newline
    size_t len = strlen(attribute_buffer);
    if (len > 0 && attribute_buffer[len-1] == '\n') {
        attribute_buffer[len-1] = '\0';
        len--;
    }

    printf("[PLC] Attribute length: %zu bytes\n", len);

    // VULNERABILITY: No bounds checking before strcpy!
    // This is the actual bug from CVE-2023-43184
    strcpy(plc_device.device_name, attribute_buffer);

    printf("[PLC] Device name set to: %.50s%s\n",
           plc_device.device_name,
           len > 50 ? "..." : "");

    // Additional vulnerability: buffer processing without bounds check
    if (len > 500) {
        printf("[PLC] WARNING: Large attribute detected!\n");

        // SECOND VULNERABILITY: Another buffer overflow
        // Processing large input without proper size checking
        sprintf(temp_buffer, "Processing device: %s", attribute_buffer);

        printf("[PLC] Processed: %.50s...\n", temp_buffer);
    }
}

/*
 * Simulate PLC ladder logic timer vulnerability
 * (Another vulnerability found by Sizzler - Timer integer overflow)
 */
void process_timer_value(uint32_t timer_value) {
    uint32_t cycles = 0;

    printf("[PLC] Setting timer to: %u\n", timer_value);

    // VULNERABILITY: Integer overflow in timer
    // If timer_value is very large (near UINT32_MAX), this causes overflow
    while (cycles < timer_value) {
        cycles++;

        // In real PLC, this would process I/O
        // Large values cause infinite loop or crash

        if (cycles == 0) {
            // Overflow detected!
            printf("[PLC] ERROR: Timer overflow detected!\n");
            abort();
        }
    }

    printf("[PLC] Timer complete\n");
}

/*
 * Main PLC runtime simulation
 */
int main(int argc, char** argv) {
    printf("========================================\n");
    printf(" PLC Modbus Handler (VULNERABLE)\n");
    printf(" Contains CVE-2023-43184\n");
    printf("========================================\n\n");

    // Initialize PLC device
    memset(&plc_device, 0, sizeof(plc_device));
    plc_device.device_id = 1;
    plc_device.device_addr = 0x1000;
    strcpy(plc_device.device_name, "DEFAULT_DEVICE");

    printf("[PLC] Initialized: %s (ID: %u)\n\n",
           plc_device.device_name,
           plc_device.device_id);

    // Read input type
    char input_type[32];
    if (fgets(input_type, sizeof(input_type), stdin) == NULL) {
        return 0;
    }

    // Process different input types
    if (strncmp(input_type, "MODBUS", 6) == 0) {
        // Process Modbus attribute (VULNERABLE!)
        process_modbus_attribute(stdin);
    }
    else if (strncmp(input_type, "TIMER", 5) == 0) {
        // Process timer value
        uint32_t timer_val;
        if (scanf("%u", &timer_val) == 1) {
            process_timer_value(timer_val);
        }
    }
    else {
        // Default processing
        char buffer[256];
        if (fgets(buffer, sizeof(buffer), stdin) != NULL) {
            printf("[PLC] Received: %s", buffer);

            // Check for magic values that trigger different code paths
            if (strstr(buffer, "CRASH") != NULL) {
                printf("[PLC] CRASH command received!\n");
                abort();
            }

            if (strstr(buffer, "OVERFLOW") != NULL && strlen(buffer) > 200) {
                printf("[PLC] Overflow detected, crashing...\n");
                // Trigger crash
                char small[10];
                strcpy(small, buffer);  // BOOM!
            }
        }
    }

    printf("\n[PLC] Processing complete\n");
    return 0;
}
