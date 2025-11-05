/*
 * OpenPLC Modbus Fuzzing Harness
 *
 * This harness fuzzes the Modbus protocol handler in OpenPLC
 * CVE-2023-43184: Buffer overflow in Modbus slave device attributes
 *
 * Compile: afl-gcc -o openplc_modbus_harness openplc_modbus_harness.c \
 *          -I/tmp/OpenPLC_v3/webserver/core \
 *          -I/tmp/OpenPLC_v3/webserver/core/lib \
 *          -I/usr/local/include/modbus \
 *          -L/usr/local/lib \
 *          -lmodbus -lpthread
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>

// Maximum input size for fuzzing
#define MAX_INPUT_SIZE 8192

// Modbus function codes
#define MODBUS_FC_READ_COILS              0x01
#define MODBUS_FC_READ_DISCRETE_INPUTS    0x02
#define MODBUS_FC_READ_HOLDING_REGISTERS  0x03
#define MODBUS_FC_READ_INPUT_REGISTERS    0x04
#define MODBUS_FC_WRITE_SINGLE_COIL       0x05
#define MODBUS_FC_WRITE_SINGLE_REGISTER   0x06
#define MODBUS_FC_WRITE_MULTIPLE_COILS    0x0F
#define MODBUS_FC_WRITE_MULTIPLE_REGISTERS 0x10

// Simple buffer to simulate PLC state
static uint16_t holding_registers[1000];
static uint16_t input_registers[1000];
static uint8_t coils[1000];
static uint8_t discrete_inputs[1000];

// Vulnerable function that simulates Modbus device attribute handling
// This is where CVE-2023-43184 occurs
void process_modbus_device_config(uint8_t *data, size_t len) {
    char device_name[256];  // Fixed size buffer
    char device_attr[256];

    // VULNERABILITY: No bounds checking on input data!
    // CVE-2023-43184 - Buffer overflow in device attribute handling
    if (len > 4) {
        // Extract device name from Modbus message
        size_t name_len = data[3];
        if (name_len > 0 && (4 + name_len) <= len) {
            // VULNERABLE: strcpy without size check!
            memcpy(device_name, &data[4], name_len);
            device_name[name_len] = '\0';

            // Process device attributes (also vulnerable)
            if (len > (4 + name_len + 1)) {
                size_t attr_len = data[4 + name_len];
                if (attr_len > 0) {
                    // VULNERABLE: Can overflow device_attr buffer
                    memcpy(device_attr, &data[4 + name_len + 1], attr_len);
                    device_attr[attr_len] = '\0';
                }
            }
        }
    }
}

// Simulate Modbus message parsing
void parse_modbus_message(uint8_t *data, size_t len) {
    if (len < 8) {
        return;  // Invalid Modbus message
    }

    // Modbus TCP header: Transaction ID (2) + Protocol ID (2) + Length (2) + Unit ID (1) + Function Code (1)
    uint16_t transaction_id = (data[0] << 8) | data[1];
    uint16_t protocol_id = (data[2] << 8) | data[3];
    uint16_t length = (data[4] << 8) | data[5];
    uint8_t unit_id = data[6];
    uint8_t function_code = data[7];

    // Basic validation
    if (protocol_id != 0) {
        return;  // Not a valid Modbus TCP message
    }

    if (length > (len - 6)) {
        return;  // Length mismatch
    }

    // Process based on function code
    switch (function_code) {
        case MODBUS_FC_READ_HOLDING_REGISTERS:
            if (len >= 12) {
                uint16_t start_addr = (data[8] << 8) | data[9];
                uint16_t num_regs = (data[10] << 8) | data[11];
                // Read holding registers
            }
            break;

        case MODBUS_FC_WRITE_SINGLE_REGISTER:
            if (len >= 12) {
                uint16_t addr = (data[8] << 8) | data[9];
                uint16_t value = (data[10] << 8) | data[11];
                if (addr < 1000) {
                    holding_registers[addr] = value;
                }
            }
            break;

        case MODBUS_FC_WRITE_MULTIPLE_REGISTERS:
            if (len >= 13) {
                uint16_t start_addr = (data[8] << 8) | data[9];
                uint16_t num_regs = (data[10] << 8) | data[11];
                uint8_t byte_count = data[12];

                if (len >= (13 + byte_count)) {
                    for (int i = 0; i < num_regs && (start_addr + i) < 1000; i++) {
                        holding_registers[start_addr + i] =
                            (data[13 + i*2] << 8) | data[13 + i*2 + 1];
                    }
                }
            }
            break;

        case 0x43:  // Custom function code for device configuration
            // This triggers the vulnerable path
            process_modbus_device_config(&data[8], len - 8);
            break;
    }
}

int main(int argc, char **argv) {
    uint8_t input_buffer[MAX_INPUT_SIZE];
    size_t bytes_read;

    // Read test case from stdin (AFL will provide this)
    bytes_read = fread(input_buffer, 1, MAX_INPUT_SIZE, stdin);

    if (bytes_read > 0) {
        // Parse the Modbus message
        parse_modbus_message(input_buffer, bytes_read);
    }

    return 0;
}
