# INVOICE - Scott Klement Invoice Demo Program

This is sample source code used as part of the "How Refactoring Helps Bulletproof Your Application" and "How Do I Improve Software Quality?" presentations by Scott Klement and Yvonne Enselman.

If you like, you can try out this application for yourself by cloning this Git repository and building it on your system.

Main website https://www.scottklement.com/presentations/

Building the Invoice Demo
---------------------------------------------------------------------
To build the invoice demo from IFS source, follow these instructions:

  1) If not already installed, you'll need YUM on your IBM i. Instructions can be found here:
       - https://ibmi-oss-docs.readthedocs.io/en/latest/yum/README.html

  2) You'll need `git` and `GNU make`. If not already installed, from a PASE command line, type:
       - `yum install git`
       - `yum install make-gnu`

  3) Clone this repository from GitHub. From a PASE command line:
       - (if your PATH isn't set up)`export PATH=/QOpenSys/pkgs/bin:$PATH` 
       - `https://github.com/ScottKlement/invoice.git`

  4) Build HTTPAPI from the PASE command line:
       - (if your PATH isn't set up) `export PATH=/QOpenSys/pkgs/bin:$PATH`
       - `cd invoice`
       - `make BUILDLIB=SKINVDEMO`

**NOTE**: To keep the messages on the screen clean and easy to follow, compile errors are not printed to the screen. Instead, files are created in the `tmp` subdirectory containing the output of the various compile commands.

Good Luck!
