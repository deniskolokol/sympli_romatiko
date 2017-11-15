#!/usr/bin/python

"""
Deploy:

$ sudo vi /lib/systemd/system/gpioswitch.service

Content:

    [Unit]
    Description=Simple GPIO button switch
    
    [Service]
    User=pi
    Group=pi
    Restart=on-abort
    ExecStart=/home/pi/switch --addres 192.168.1.132 --port 57120 --pin 18
    
    [Install]
    WantedBy=multi-user.target
    Alias=gpioswitch.service

Reload sysctl daemon:

    $ sudo sysctl daemon-reload

"""

import sys
import time
import datetime
import optparse
import OSC
import RPi.GPIO as GPIO


def send_osc(client, msg):
    msg.setAddress("/action")
    msg.extend(['event', 1])
    try:
        client.send(msg)
    except OSC.OSCClientError as err:
        print >> sys.stderr, "%s OSC.OSCClientError %s\n" % (
            datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f'), err
            )


def main(opts):
    # connect to SuperCollider
    client = OSC.OSCClient()
    client.connect((opts.ip_addres, int(opts.port)))
    oscmsg = OSC.OSCMessage()

    # setup GPIO
    pin = int(opts.pin_number)
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)

    state = GPIO.input(pin)

    while True:
        if state != GPIO.input(pin):
            state = GPIO.input(pin)
            send_osc(client, oscmsg)
        time.sleep(0.2)

    GPIO.cleanup()


if __name__ == '__main__':
    cmdparser = optparse.OptionParser(usage="usage: %prog [OPTIONS]")
    cmdparser.add_option(
        "-a", "--addres", action="store", dest="ip_addres", default='127.0.0.1',
        help="IP address of the receiver [default \'%default\']"
        )
    cmdparser.add_option(
        "-p", "--port", action="store", dest="port", default=57120,
        help="IP port of the receiver [default \'%default\']"
        )
    cmdparser.add_option(
        "-n", "--pin", action="store", dest="pin_number", default=18,
        help="GPIO pin number [default \'%default\']"
        )
    opts, args = cmdparser.parse_args()
    main(opts)
