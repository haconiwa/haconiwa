#!/bin/bash

logger -t haconiwa.action-script -si Hello!
logger -t haconiwa.action-script -si "CRTOOLS_SCRIPT_ACTION: $CRTOOLS_SCRIPT_ACTION"
logger -t haconiwa.action-script -si "CRTOOLS_IMAGE_DIR: $CRTOOLS_IMAGE_DIR"
logger -t haconiwa.action-script -si "CRTOOLS_INIT_PID: $CRTOOLS_INIT_PID"
exit
