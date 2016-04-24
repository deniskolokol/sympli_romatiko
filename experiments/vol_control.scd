(
// start server
s.waitForBoot({

    var w, controls, sliders, buttons, synths, nodes, channels;
    var view, cmdPeriodFunc, initGroup;

    synths = [\sr__e__lowe, \sr__e__probe, \sr__e__cmb, \sr__e__melo,
        \sr__e__ringz, \sr__e__pulse, \sr__e__analog, \sr__e__entro,
        \sr__e__noisy, \sr__e__humm, \sr__e__radio];
    sliders = buttons = nodes = Array.fill(synths.size, {nil});

    // make the window
    w = Window("another control panel", Rect(20, 400, 500, synths.size * 30));
    w.front; // make window visible and front window.
    w.view.decorator = FlowLayout(w.view.bounds);
    w.view.decorator.gap = 2@2;

    // create controls for all parameters
    controls = synths.collect { |synth, i|
        w.view.decorator.nextLine;
        view = CompositeView(w, Rect(0, i * 25, w.bounds.width, 25));

        // volume slider
        sliders[i] = EZSlider(view, Rect(90, 0, w.bounds.width - 100, 25), synth, \amp,
            {|ez| if (nodes[i].isNil.not) {nodes[i].set(\amp, ez.value)}}, 0
        ).setColors(Color.grey,Color.white, Color.grey(0.7),Color.grey, Color.white, Color.yellow);

        // add a button to start and stop the sound
        buttons[i] = Button(view, Rect(0, 0, 85, 25))
        .states_([
            ["Start", Color.black, Color.green(0.7)],
            ["Stop", Color.white, Color.red(0.7)]
        ])
        .action_({ |b|
            if (b.value == 1) { // start sound
                //nodes[i] = Synth(synth, [\amp, sliders[i].value, \distance, 0.1, \azimuth, 0, \velocity, 1, \outbus, i % 2]);
                nodes[i] = Synth(synth, [\amp, sliders[i].value, \distance, 0.1, \azimuth, 0, \velocity, 1, \outbus, 0]);
            } { // set gate to zero to cause envelope to release
                nodes[i].release;
                nodes[i] = nil;
            };
        });

    };
    // set start button to zero upon a cmd-period
    cmdPeriodFunc = {
        nodes.do { |n| n.release};
        w.close;
    };
    CmdPeriod.add(cmdPeriodFunc);
    w.front; // make window visible and front window.

    // stop the sound when window closes and remove cmdPeriodFunc.
    w.onClose = {
            CmdPeriod.remove(cmdPeriodFunc);
    };
})
)



// a = Synth(\sr__e__noisy, [\amp, 1, \distance, 0.1, \azimuth, 0, \velocity, 1])
// a.set(\amp, 0.8)
