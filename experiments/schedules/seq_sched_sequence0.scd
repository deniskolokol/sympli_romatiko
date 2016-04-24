d = (
        0.0: ( // Initial params.
            message: \worldpar,
            params: [\starMass, 120]
        ),
        1.0: ( // Launch background pulse.
            message: \s_new,
            synth: (
                id: \start_pulse_0,
                name: \sr_bg_pulse,
                params: [\busnum, 30, \att, 20, \crva, 3, \freq, 4] // 30 - goes into AudioIn, fade-in 20s
            )
        ),
        60.0: ( // Inrease average freq.
            message: \n_set,
            synth: (
                id: \start_pulse_0,
                params: [\freq, 8]
            )
        ),
        90.0: ( // Decrease and change freq of background pulse.
            message: \n_set,
            synth: (
                id: \start_pulse_0,
                params: [\freq, 6]
            )
        ),
        91.0: ( // Launch the first object.
            message: \worldobj,
            synth: (
                name: \sr_pulse,
            ),
            object: (
                type: "a RedBoid",
                age: 50,
                mass: 1.8
            )
        ),
        110.0: ( // Launch another object.
            message: \worldobj,
            synth: (
                name: \sr_pulse,
            ),
            object: (
                type: "a RedObject",
                age: 50,
                mass: 3
            )
        ),
        110.0: ( // Launch a loop.
            message: \worldobj,
            synth: (
                name: \sr_loop,
            ),
            object: (
                type: "a RedObject",
                age: 30,
                mass: 1.2
            )
        ),
        150.0: ( // Increase entropy.
            message: \worldpar,
            params: [\starMass, 5000]
        ),
        155.0: ( // Particles on.
            message: \worldpar,
            params: [\particles, true, \partAgeThresh, 70, \partFreq, 0.26]
        ),
        161.0: ( // SUBSTANTIALLY increase entropy.
            message: \worldpar,
            params: [\partFreq, 0.07]
        ),
        165.0: ( // Decrease entropy.
            message: \worldpar,
            params: [\starMass, 120]
        ),
        170.0: ( // Particles off.
            message: \worldpar,
            params: [\particles, false]
        ),
        171.0: ( // Set particles frequency back to "normal".
            message: \worldpar,
            params: [\partFreq, 0.25]
        ),
        172.0: ( // Inrease average freq.
            message: \n_set,
            synth: (
                id: \start_pulse_0,
                params: [\freq, 8]
            )
        ),

        // GAP for m1, m2: 169 - 600

        // Release background pulse.
        360.0: (
            message: \n_set,
            synth: (
                id: \start_pulse_0,
                params: [\rel, 120, \gate, 0]
            )
        )
    )