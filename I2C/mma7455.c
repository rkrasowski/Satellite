/* Accelerometer Program: mma7455.c */
/* http://code.google.com/p/hid2011/source/browse/testapps/mma7455.c */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <linux/i2c.h>
#include <linux/i2c-dev.h>
#include <unistd.h>
#include <sys/ioctl.h>

/* The 7-bit address */
#define MMA7455_I2CADDR 0x1D

/* The mode control register address */
#define MMA7455_CTRLADDR 0x16

/* The control value "0100 0101" */
#define MMA7455_CTRLREG_VAL 0x45

/* The registers to read */
#define MMA7455_XOUT8 0x6
#define MMA7455_YOUT8 0x7
#define MMA7455_ZOUT8 0x8

/* The name of the file */
#define I2C_FILE_NAME "/dev/i2c-2"

static int set_i2c_register(int file,
                            unsigned char addr,
                            unsigned char reg,
                            unsigned char value) {
    unsigned char outbuf[2];
    struct i2c_rdwr_ioctl_data packets;
    struct i2c_msg messages[1];

    messages[0].addr  = addr;
    messages[0].flags = 0;
    messages[0].len   = sizeof(outbuf);
    messages[0].buf   = outbuf;

    /* The first byte indicates which register we'll write */
    outbuf[0] = reg;

    /* The second byte indicates the value to write.  Note that for many *
     * devices, we can write multiple, sequential registers at once by   *
     * simply making outbuf bigger.                                      */
    outbuf[1] = value;

    /* Transfer the i2c packets to the kernel and verify it worked */
    packets.msgs  = messages;
    packets.nmsgs = 1;
    if(ioctl(file, I2C_RDWR, &packets) < 0) {
        /* Error Indication */
        perror("Unable to send data");
        exit(1);
    }
    /* Success Indication */
    return 0;
}

static int get_i2c_register(int file,
                            unsigned char addr,
                            unsigned char reg,
                            unsigned char *val) {
    unsigned char inbuf, outbuf;
    struct i2c_rdwr_ioctl_data packets;
    struct i2c_msg messages[2];

    /* In order to read a register, we first do a "dummy write" by writing  *
     * 0 bytes to the register we want to read from.  This is similar to    *
     * the packet in set_i2c_register, except it's 1 byte rather than 2.    */
    outbuf = reg;
    messages[0].addr  = addr;
    messages[0].flags = 0;
    messages[0].len   = sizeof(outbuf);
    messages[0].buf   = &outbuf;

    /* The data will get returned in this structure */
    messages[1].addr  = addr;
    messages[1].flags = I2C_M_RD;
    messages[1].len   = sizeof(inbuf);
    messages[1].buf   = &inbuf;

    /* Send the request to the kernel and get the result back */
    packets.msgs      = messages;
    packets.nmsgs     = 2;
    if( ioctl(file, I2C_RDWR, &packets) < 0 ) {
        /* Error Indication */
        perror("Unable to send data");
        exit(1);
    }
    /* Success Indication */
    *val = inbuf;
    return 0;
}

int main(int argc, char **argv) {
    int i2c_file;
    int8_t x, y, z;  /* The readings are 8 bits and signed */

    /* Open a connection to the I2C userspace control file */
    if ((i2c_file = open(I2C_FILE_NAME, O_RDWR)) < 0) {
        /* Error Indication */
        perror("Unable to open i2c control file");
        exit(1);
    }
    /* Success Indication */
 //   printf("Initialized\n");

    /* Set control register */
    if( set_i2c_register(i2c_file, MMA7455_I2CADDR, MMA7455_CTRLADDR, 0x45) ) {
        /* Error Indication */
        printf("Unable to set control register!\n");
        return -1;
    }
    /* Success Indication */
   // printf("Set control register successfully\n");

// MOje






  //  while (1) {
     /*    Read X, Y, and Z from the register */
        if( get_i2c_register(i2c_file, MMA7455_I2CADDR, MMA7455_XOUT8, &x) ||
            get_i2c_register(i2c_file, MMA7455_I2CADDR, MMA7455_YOUT8, &y) ||
            get_i2c_register(i2c_file, MMA7455_I2CADDR, MMA7455_ZOUT8, &z) ) {

            /* Error Indication */
            printf("Unable to read register\n");
            return -1;
        }
        /* Success Indication */

        /* Debug line that prints out registers */
        printf("%d\t|%d\t|%d\n", x, y, z);
	
   // }
   /* Cleanup and Exit */
    close(i2c_file);
    return 0;
}



