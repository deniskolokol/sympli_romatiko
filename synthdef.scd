//    arg:
// inbus => in
// outbus => out
// att => attack
// rel => release
// momentum => momentum
// offset => \ (shold receive a note!)
//
//    var:
// in => signal (no diff between in and signal anymore)
// out => output
//
(
var outFuncName, outCodeFunc;

// default speaker placement configurations
var spatialConf = (
    "a2": (
        azim: #[-0.25pi, -0.75pi],
        elev: #[0, 0],
        dist: #[2, 2],
        maxDist: 2
    ),
    "a4": (
        azim: #[-0.25pi, -0.75pi, 0.75pi, 0.25pi],
        elev: #[0, 0, 0, 0],
        dist: #[2, 2, 2, 2],
        maxDist: 2
    ),
    // "a6": (
    //     azim: #[-0.25pi, -0.5pi, -0.75pi, 0.75pi, 0.5pi, 0.25pi],
    //     elev: #[0, 0, 0, 0, 0, 0],
    //     dist: #[2, 2, 2, 2, 2, 2],
    //     maxDist: 2
    // ),
    // "a8": (
    //     azim: #[-0.25pi, -0.5pi, -0.75pi, 1pi, 0.75pi, 0.5pi, 0.25pi, 0],
    //     elev: #[0, 0, 0, 0, 0, 0, 0, 0],
    //     dist: #[2, 2, 2, 2, 2, 2, 2, 2],
    //     maxDist: 2
    // ),
    // "a10": (
    //     azim: #[-0.15, -0.25pi, -0.5pi, -0.75pi, 1pi, 0.75pi, 0.5pi, 0.25pi, 0.15pi, 0],
    //     elev: #[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    //     dist: #[2, 2, 2, 2, 2, 2, 2, 2, 2, 2],
    //     maxDist: 2
    // ),
);

// GENERATORS
//
var makeSynthDefPerc = { |name, outCodeFunc|
    // XXX - former \sr__e__perc
    SynthDef("kick__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi;
        var lag=0.25;
        var trig = momentum > 0.2;
        var timer = Timer.kr(trig);
        var att = momentum.linexp(0.0, 1.0, 0.0, 0.2);
        var rel = 1 - momentum;
        var gt = (timer > lag) * trig;
        var signal = Pulse.ar(freq,
            width: PinkNoise.kr((ExpRand(0.009, momentum*0.9)*amp).min(0.45), 0.45),
            mul: FSinOsc.ar(LinRand(9, 99*freq).round(9), 0, LinRand(0.09, 0.999-momentum), amp)
        ) * 0.5;
        signal = RLPF.ar(signal,
            freq: (freq*9*momentum).max(freq*4.5),
            rq: LinRand(0.09, 4.5)
        ).softclip;
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gt, att, rel, depth, elevClip
        );
    }).add;
};

var makeSynthDefADSR = { |name, outCodeFunc|
    // XXX - former \sr__e__silent
    SynthDef("silent__" ++ name, {
        arg out=0, trigID=80,
            azimuth= -0.5pi, distance=0.1, elevation=0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            depth=5, elevClip=0.01pi;
        var signal = Silent.ar();
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;

    // audio-through
    // XXX - former \sr__r__authro
    SynthDef("atru__" ++ name, {
        arg bufnum=0, in=0, out=0, trigID=80, amp=1,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            depth=5, elevClip=0.01pi;
        var signal, ds;
        ds = distance/3.44;
        signal = RLPF.ar(
            DelayL.ar(
                FreeVerb.ar(
                    InFeedback.ar(in, 1),
                    distance.clip(0.01, 1), ds, 0.2
                ), 0.3, ds
            ), distance.linlin(0, 2.sqrt, 10000, 1000), 0.5
        );
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;

    // XXX former \sr__g__scratch
    // ~ chunks of sound
    SynthDef("scratch__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi;
        var ds = distance/3.44;
        var rate = momentum.clip(0.1, 1.9);
        var pos = gx * BufDur.kr(bufnum); // gx for finer control (instead of ax)
        var signal = BufRd.ar(
            1, bufnum, Lag.ar(K2A.ar(BufFrames.ir(bufnum) * pos), 4), 1
        ) * amp;
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // XXX former \sr__g__reg
    SynthDef("greg__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi;
        var ds = distance/3.44;
        var rate = az.linlin(0, 1, 0.8, 1.2);
        var tRate = az.linlin(0, 1, 100, 0.2);
        var tDur = 4 / tRate;
        var clk = Dust.kr(tRate);
        var pos = Integrator.kr(BrownNoise.kr(ds));
        var raw = TGrains.ar(2, clk, bufnum, BufRateScale.kr(bufnum) * rate, pos, tDur);
        var signal = Mix.ar(raw) * amp;
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // XXX former \sr__g__drone
    SynthDef("drone__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi;
        var ds = distance/3.44;
        var rate = az.linlin(0, 1, 0.2, 2);
        var tRate = SinOsc.kr(0.016, 0, 21, 20); //1-40, 0.016 - once a minute;
        var tDur = 12 / tRate;
        var clk = Impulse.kr(tRate);
        var pos = ax * BufDur.kr(bufnum);
        var raw = TGrains.ar(
            2, clk, bufnum, BufRateScale.kr(bufnum) * rate, pos + TRand.kr(0, 0.01, clk), tDur
        );
        var signal = Mix.ar(in) * amp;
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // XXX former \sr__g__unst
    SynthDef("unst__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi,
            pos=0, rate=1;
        var ds = distance/3.44;
        var raw = PlayBuf.ar(1,
            bufnum,
            TWChoose.kr(
                Dust.kr(0.01),
                [
                    BufRateScale.kr(bufnum) * TRand.kr(0.8, 1.1, Dust.kr(2)),
                    BufRateScale.kr(bufnum) * TRand.kr(-0.8, -1.1, Dust.kr(2)),
                ],
                [0.6, 0.4]),
            Dust.kr(0.2),
            TRand.kr(0, BufFrames.ir(bufnum), Dust.kr(0.2))
        );
        var signal = RLPF.ar(
            FreeVerb.ar(raw, distance.clip(0.01, 1), ds),
            distance.linlin(0, 2.sqrt, 10000, 1000),
            0.5
        ) * amp;
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // XXX former \sr__g__loopdel
    SynthDef("loopdel__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi,
            pos=0, rate=1;
        var ds = distance/3.44;
        var raw = PlayBuf.ar(1,
            bufnum,
            // slight disturbances of rate
            BufRateScale.kr(bufnum) * (rate + LFNoise1.kr(LFNoise1.ar(1.4, 1, 1.6), 0.15)),
            Impulse.ar(BufDur.kr(bufnum).reciprocal),
            BufFrames.ir(bufnum) * pos
        );
        var signal = DelayL.ar(raw, 0.3, ds) * amp;
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // XXX former \sr__g__loop
    SynthDef("loop__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi,
            pos=0, rate=1;
        var ds = distance/3.44;
        var signal = PlayBuf.ar(1,
            bufnum,
            // slight disturbances of rate
            BufRateScale.kr(bufnum) * (rate + LFNoise1.kr(LFNoise1.ar(1.4, 1, 1.6), 0.15)),
            Impulse.ar(BufDur.kr(bufnum).reciprocal),
            BufFrames.ir(bufnum) * pos
        ) * amp;
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // ~ gusts of wind
    // XXX former \sr__g__gust
    SynthDef("gust__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi;
        var ds = distance/3.44;
        var tPos = (distance * 0.19 + 0.1).round(0.01);
        var trate = az.linlin(0, 1, 0.1, 20);
        var clk = Impulse.ar(trate);
        var d = {Dwhite(0.1, 0.2, 1)};
        var zz = {Drand([Dgeom(0.1, 1 + d.value, Diwhite(20, 40)), Dgeom(1, 1 - d.value, Diwhite(20, 40))])};
        var raw = TGrains.ar(2, clk, bufnum,
            rate: Dseq([1, 1, zz.value, 0.5, 0.5, 0.2, 0.1, 0.1, 0.1, 0.1], inf) * tPos + 1,
            centerPos: Dseq(zz.dup(8), inf) / tPos,
            dur: Dseq([1, d.value, 1, zz.value, 0.5, 0.5, 0.1, zz.value] * 2, inf) / trate,
            amp: Dseq([1, 0, zz.value.min(1.3), 0, 0.6, 0.3, 1, 0.1, 0.1], inf)
        );
        var signal = Mix.ar(in) * amp; // XXX - add Compander to smooth out violent dynamics!
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // XXX former \sr__e__gauss
    SynthDef("gauss__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi;
        var signal;
        var cutOff = distance.linexp(0.0, 1.0, 10000, 200); // different from arg cutoff!
        var rq = distance.linexp(0, 2.sqrt, 1, 0.2);
        var tDur = SinOsc.ar(LinExp.kr(az, 0.001, 1, 0.05, 5000) * [1, 1.1]).range(0.0006, 0.01);
        var width = SinOsc.ar(0.5 * [1, 1.1]).range(0.01, 0.3);
        var lag = momentum.lincurve(0, 1, 0.5, 0.05, -4);
        var rate = momentum.linlin(0, 1, 2, 4).round;
        var trig = Impulse.kr(0) + Dust2.kr(rate);
        var raw = (
            LFGauss.ar(tDur, width)
            + SinOsc.ar(az.linexp(0, 1, 0.01, 5000) * [1, 1.1])
        )
        * amp
        // amp controlled by momentum, when "behind the back"
        * SelectX.kr(BinaryOpUGen('<', ay, 0.5),
            [
                (az.clip(0, 1) * momentum).sqrt, // sqrt boosts mul
                Lag.kr(TRand.kr(0.8, 1.0, trig), lag * Rand(0.8, 1.2))
            ]
        );
        raw = Limiter.ar(
            in: MidEQ.ar(Mix.fill(10, raw), 14000, momentum.lincurve(0, 1, 0.8, 0.1, 2), 8),
            level: 0.2
        );
        signal = RLPF.ar(RLPF.ar(Mix.ar(raw), cutOff, rq), cutOff, rq); // XXX profile this contruct: RLPF(RLPF) w/same params
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // XXX former \sr__e__probe
    SynthDef("probe__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi,
            offset=36, scope=12; // XXX =- move this to LFO synth (modulator with DegreeToKey)
        var signal;
        // XXX
        // some params should be functions of [ax, ay, az], but some
        // of [gx, gy, gz], ideally this will create a feeleing of "flow",
        // in which aX changes come slower than gX
        // can also be applied to voices!
        var rate = (momentum*5).max(0.1) * exprand(3, 8);
        var note = DegreeToKey.kr(bufnum, az * scope, 12, 1, offset);
        // Synthesis.
        var raw = LPZ2.ar(
            LFPulse.ar(
                note.midicps, 2pi.rand, 0.1,
                (
                    Mix.ar(SinOsc.ar(rate * [rrand(0.7, 1.3), 1], [2pi.rand, 2pi.rand], 0.04)).max(0)
                    * Mix.ar(SinOsc.ar(exprand(6,24) * [rrand(0.7, 1.3), 1], [2pi.rand, 2pi.rand])).abs
                )
            )
        );
        2.do({ raw = AllpassN.ar(raw, 0.05, [0.01, 0.05], 3.0.rand, amp) });
        signal = Limiter.ar(MidEQ.ar(Mix(raw), 1400, 0.7, 8), 0.8);
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // Theremin
    // XXX - former \sr__e__therem
    SynthDef("therem__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi;
        var signal, raw;
        var baseFreq=50000;
        // XXX - do not re-assign param \freq, solve it with modulator!
        freq = az.linexp(0.5, 1, baseFreq, baseFreq + 5000);
        raw = BPF.ar(
            (SinOsc.ar(baseFreq, 0, amp) * SinOsc.ar(freq)),
            freq - (baseFreq - 50),
            0.3
        );
        raw = MidEQ.ar(raw, freq-38500, 0.7, -60);
        signal = FreeVerb.ar(raw, 0.65, 0.65, 0.5, (amp*1.5).clip(0, 1));
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // XXX former \sr__e__pulse
    SynthDef("pulse__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi,
            offset=36;
        var signal;
        var azThresh=0.7;
        var cutOff = distance.linexp(0.0, 1.0, 200, 10000); // different from arg!
        var rq = distance.linlin(0, 2.sqrt, 0.5, 1);
        var note = SelectX.kr(BinaryOpUGen('<', az, azThresh) * 2,
            [ // go melodic above height threshold
                DegreeToKey.kr(bufnum, (az - azThresh).linlin(0, 1 - azThresh, 0, 12), 12, 1, offset).midicps,
                momentum.linlin(0, 1, 5, 150) // continuos change at the bottom
            ]
        );
        var raw = Blip.ar(SinOsc.kr(0.5, 0, LFDNoise1.kr(1.5), note), 100, 0.2);
        raw = RLPF.ar(RLPF.ar(Mix.fill(10, raw), cutOff, rq), cutOff, rq);
        raw = Limiter.ar(MidEQ.ar(raw, [200, 1400], 0.7, 8), amp * 0.1);
        signal = Mix.ar(raw);
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // CMB => "Cosmic Backgroud Radiation"
    // XXX former \sr__e__cmb
    SynthDef("cmb__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi;
        var raw, signal;
        var rate=1, delayL, delayR, pos=0.0, pulse, mix, n=8;
        rate = az.linlin(0, 1, 2, 0.2);
        delayL = az.linlin(0, 1, 0.01, 0.05);
        delayR = ax.linlin(0, 1, 0.01, 0.05);
        pulse = LFNoise0.kr(rrand(0.2,1.0), 1,1).squared * rate;
        mix = Klank.ar(
            `[Array.fill(n, {exprand(1.0,20.0)}),
                nil,
                Array.fill(n, {0.2.rand})
            ],
            Blip.ar(pulse, [rrand(2,5), rrand(2,5)], 0.1)
        ).fold2(0.2).cubed * 12;
        raw = Mix.fill(3, {CombL.ar(mix, 0.1, 0.03.linrand, 4.0.linrand)});
        raw = raw.distort * 0.5;
        6.do({ raw= AllpassN.ar(raw, 0.05, [0.05.rand, 0.05.rand], 3) });
        signal = LeakDC.ar(raw * 0.5);
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // XXX former sr__e__melo
    SynthDef("melo__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi,
            offset=36, cutoff=20000, rq=0.1;
        var signal;
        var note = (
            DegreeToKey.kr(bufnum, az.linlin(0, 1, 0, 24), 12, 1, offset)
            + LFNoise1.kr([3,3], 0.04)    // add some low freq stereo detuning
        ).midicps;
        var gen = (
            LFSaw.ar(note)
            +
            Impulse.ar(
                XLine.kr(note, note + 100, 1.5),
                0.0
            )
            + Normalizer.ar(
                LorenzL.ar(
                    az.linlin(0, 1, 10, SampleRate.ir),
                    LFNoise0.kr(1.0.rand, 2, 10),
                    r: LFNoise0.kr(1.0.rand, 20, 38),
                    b: LFSaw.kr(0.2).exp.cubed
                ),
                1
            )
        );
        var raw = RLPF.ar(
            gen,
            cutoff, // LFNoise0.kr(0.2, 38, 115).midicps,
            rq,
            mul:(amp * momentum * 0.5).scurve // sigmoid: the faster, the more present
            // mul:momentum // simply the faster the louder
        );
        raw = [raw, DelayN.ar(raw, 0.04, 0.04)];
        4.do({raw = AllpassN.ar(raw, 0.05, [0.05.rand, 0.05.rand], 4)});
        signal = Mix.ar(raw);
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    SynthDef("humm__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi,
            offset=36;
        var note = (DegreeToKey.kr(bufnum, az.linlin(0, 1, 0, 15), 12, 1, offset)
            + LFNoise1.kr([3, 3], 0.04)).midicps;    // add some low freq stereo detuning
        var raw = Mix.ar(
            LFSaw.ar((1..5) * note, abs(momentum * 2), momentum)
            + Impulse.ar((0..4) + SinOsc.ar((4..8) * note).exprange(0.3, 300))
        ) * amp * 0.1;
        var signal = RLPF.ar(raw, LinLin.kr(momentum, 0, 1, 80, 30).midicps, momentum);
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // "Entropia"
    // XXX former \sr__e__entro
    SynthDef("entro__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi,
            cutoff=20000, rq=0.7;
        var rQ = distance.linlin(0, 2.sqrt, rq, 0.01);
        var shift = momentum.lincurve(0, 1, 5, cutoff, -5).lag(0.3); // boost momentum
        var trig = momentum > 0.2;
        var timer = Timer.kr(trig);
        var raw = TChoose.ar(
            (timer > 0.25) * trig, [
                RLPF.ar(
                    Normalizer.ar(
                        LorenzL.ar(
                            az.linlin(0, 1, 10, SampleRate.ir),
                            LFNoise0.kr(1, 2, 10),
                            r: LFNoise0.kr(1, 20, 38),
                            b: LFSaw.kr(0.2).exp.cubed
                        ),
                        1
                    ),
                    LFPulse.kr(LFSaw.ar(0.2).exp.cubed, 0.5, 2500, 3500),
                    momentum.scurve
                ),
                Mix.ar(
                    Saw.ar(
                        (1..15) * LFNoise0.kr(5, 10, 50) + SinOsc.ar((6..2) * 0.5)
                    )
                )
            ]
        ) * momentum * amp;
        var signal = RLPF.ar(RLPF.ar(raw, shift, rQ), shift, rq);
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // XXX:
    // - add less obvious elevation based control (az)
    // - more effective compander, possibly multiband! don't allow it to burst!
    SynthDef("neural__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi;
        var signal;
        var mul = momentum.linlin(0, 1, 1850, 2350);
        var add = distance.linlin(0, 1, 2250, 5800);
        var trig = momentum > 0.33; // high momentum causes sharp switch
        var timer = Timer.kr(trig);
        var baseFreq = TRand.kr(trig:Delay2.kr(Dust.kr(momentum.linexp(0.01, 1, 0.5, 10))));
        var rq = momentum.linlin(0, 1, 0.8, 0.2);
        var cutoff = TWChoose.kr((timer > 0.25) * trig,
            [
                LFNoise0.ar(baseFreq, mul, add),
                LFNoise1.ar(baseFreq, mul, add),
                LFNoise2.ar(baseFreq).clip2 * mul + add // quadratic interpolation can push beyond [-1..1]
            ],
            [0.1, 0.3, 0.6]
        );
        var raw = TermanWang.ar(
            2.0 + SinOsc.ar(az.linexp(0.01, 1, 10, 10000), 0, az.linexp(0.01, 1, 0.1, 100.0)),
            Impulse.kr(distance.linexp(0.01, 1, 1, 10000)),
            0.01, 0.01, 1.0, 1.0, 1.0,
            ax.linlin(0, 1, 0.4, 1.2), ay.linlin(0, 1, 2.0, 4.0)
        );
        raw = RLPF.ar(raw, cutoff, rq);
        signal = Compander.ar(raw, raw, 0.1, slopeBelow: 1, slopeAbove: 0.5,
            clampTime: 0.01, relaxTime: 0.01, mul: amp);
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // XXX - former \sr__e__radio
    SynthDef("komar__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi,
            min= -1, max=1, cutoff=250, rq=0.5, melo=0;
        var trig = momentum > 0.3;
        var timer = Timer.kr(trig);
        var impFreq = TChoose.ar((timer > 0.25) * trig, [
            LFDClipNoise.ar(az, 450, 650),
            LFNoise2.ar(TRand.kr(trig: Delay2.kr(Dust.kr(0.2))), 450, 550)
        ]);
        var impMin = min.linlin(-1, 0.99, 3, 1200);
        var impMax = max.linlin(-0.99,  1, 1201, 20000);
        var note = SelectX.kr(BinaryOpUGen('>', melo, 0) * 2,
            [
                // Zero or negative \melo means constant value
                freq,

                // Positive \melo asks for DegreeToKey
                DegreeToKey.kr(bufnum, az.linlin(0, 1, 0, 24), 12, 1, freq.cpsmidi).midicps
            ]
        );
        var raw = (
            LFSaw.ar(note, mul:momentum)
            + Impulse.ar(SinOsc.ar(impFreq).exprange(impMin, impMax), mul:momentum)
            + Formlet.ar(
                Impulse.ar(note + SinOsc.ar(note * 0.02).exprange(0.3, impFreq / 3.67)),
                (1..5)
                * SinOsc.ar(momentum).exprange(20, 2000)
                * SinOsc.ar(SinOsc.ar(momentum, 0, 0.1), 0, 0.1, 1), 0.001, 0.0015,
                mul: momentum.scurve
            )
        );
        var signal = Mix.ar(raw) * amp * 0.5;
        signal = RLPF.ar(RLPF.ar(signal, cutoff, rq), cutoff, rq); // XXX profile this contruct: RLPF(RLPF) w/same params
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // XXX - former \sr__e__noisy
    SynthDef("wind__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi,
            delay=0.4, decaytime=4, melo=0;
        var signal;
        var baseFreq = distance.linexp(0, 1, 10, 40).lag(0.01);
        var shift = ((momentum * 30) ** 3).lag(0.01);
        var note = SelectX.kr(BinaryOpUGen('>', melo, 0) * 2,
            [
                // Positive \melo means value controlled by momentum
                LFNoise1.ar(TRand.kr(trig:Delay2.kr(Dust.kr(0.5))), 2450, 2550),

                // Zero or negative \melo asks for LFNoise1
                momentum.linexp(0, 1, 5000, 100),
            ]
        );
        var raw = Formlet.ar(
            in: (
                WhiteNoise.ar(SinOsc.ar(baseFreq, shift, 0.5, 1)).min(1)
                + SinOsc.ar(baseFreq, shift)
            ),
            freq: note,
            attacktime: 0.01,
            decaytime: 0.1
        ).softclip;
        raw = [raw, DelayN.ar(raw, 0.04, delay)];
        4.do({raw = AllpassN.ar(raw, 0.5, [0.5.rand, 0.5.rand], decaytime, amp)});
        signal = Mix.ar(raw) * 0.2;
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;


    // The "lowe"st.
    // XXX - former \sr__e__lowe
    // XXX - in orig synth \freq was a var with default val 400
    SynthDef("lowe__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
        gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
        ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
        gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
        depth=5, elevClip=0.01pi;
        var signal;
        var q=0.1, a=2pi, b=400, c=0, dir=[1, 0], frate=1, xx=(1..5)*20;
        dir = dir.put(1, az.linlin(0, 1, -pi, pi));
        dir = dir.put(0, ax.linlin(0, 1, -pi, pi));
        q = dir[1].atan2(dir[0]) + pi;
        a = frate.linlin(0,2, 2pi, 0);
        b = dir[1].hypot(dir[0]) * 400 + 250;
        c = momentum.linlin(0, 1, 100, 150);
        // signal = SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q), amp);
        // signal = RLPF.ar(Limiter.ar(Mix.ar(signal)), distance.linlin(0, 2.sqrt, 500, 10000), 0.5);
        signal = SinOsc.ar(c, BPF.ar(BPF.ar(LFSaw.ar(freq * xx, 0, a), b), xx, q));
        signal = RLPF.ar(Mix.ar(signal), distance.linlin(0, 2.sqrt, 500, 10000), 0.5);
        signal = Limiter.ar(signal, amp);
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;

    SynthDef("buzz__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi;
        var signal;
        signal = Mix.new([
            LFSaw.ar((1..5) * freq, abs(momentum * 2)),
            Impulse.ar((0..4) + SinOsc.ar((4..8) * freq).exprange(0.3, 300))
        ]) * amp * 0.07;
        signal = RLPF.ar(signal, LinLin.kr(momentum, 0, 1, 80, 30).midicps, momentum);
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;

    // "POLE - POLyphonic Electronic synth"
    // XXX - former \sr__e__growl
    SynthDef("pole__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=73, amp=1.0, dur=0.1,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.1,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi,
            voices=10, lfreq=1.5, melo=0;
        var rq = momentum.lincurve(0, 1, 0.6, 0.01, 4);
        var mul = momentum.lincurve(0, 1, 400, 2000, 4);
        var add = momentum.lincurve(0, 1, 600, 10000, 4);
        var cutoff = LFNoise2.ar(momentum).clip2 * mul + add;
        var trig = Dust2.kr(momentum.linlin(0, 1, 1, 100).round);
        var lag = momentum.lincurve(0, 1, 0.5, 0.05, -4);
        var detune = momentum.lincurve(0, 1, 0.4, 0.5, 4);
        var tones = 20;
        var note = SelectX.kr(BinaryOpUGen('>', melo, 0) * 2,
            [
                // Zero or negative \melo means constant value
                freq,

                // Positive \melo asks for DegreeToKey
                DegreeToKey.kr(bufnum, az.linlin(0, 1, 0, 12), 12, 1, freq.cpsmidi).midicps
            ]
        )
        + TRand.kr(detune.neg, detune, trig);
        var signal = Mix.fill(tones,
            { |index|
                var pitches = Lag.kr(
                    note,
                    lag * Rand(0.8, 1.2)
                );
                Blip.ar(
                    SinOsc.kr(0.5, 0, LFDNoise1.kr(lfreq), pitches),
                    100,
                    Lag.kr(TRand.kr(0.8, 1.0, trig), lag * Rand(0.8, 1.2)),
                )
                * (
                    if(index < voices, voices.reciprocal+0.2, 0)
                );
            }
        );
        signal = MidEQ.ar(signal, [200, 1400], 0.7, 8);
        signal = RLPF.ar(RLPF.ar(signal, cutoff, rq), cutoff, rq);
        signal = Limiter.ar(Mix.ar(signal), amp);
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;

    // XXX - former \sr__e__perc
    SynthDef("bass__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi;
        var mix, room, signal;
        var trig, timer, lag=0.25;
        trig = momentum > 0.2;
        timer = Timer.kr(trig);
        signal = Pulse.ar(
            freq,
            width: PinkNoise.kr((ExpRand(0.009, momentum*0.9)*amp).min(0.45), 0.45),
            mul: FSinOsc.ar(LinRand(9, 99*freq).round(9), 0, LinRand(0.09, 0.999-momentum), amp)
        ) * 0.5;
        signal = RLPF.ar(signal,
            freq: (freq*9*momentum).max(freq*4.5),
            rq: LinRand(0.09, 4.5)
        ).softclip;
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;

    // XXX former \sr__e__analog
    SynthDef("moog__" ++ name, {
        arg bufnum=0, in=30, out=0, trigID=80, freq=432, amp=1.0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            ax=0.1, ay=0.1, az=0.1, azimuth= -0.5pi, distance=0.1, elevation=0, momentum=0.3,
            gx=0.1, gy=0.1, gz=0.1, gAzimuth= -0.5pi, gDistance=0.5, gElevation=0.5,
            depth=5, elevClip=0.01pi,
            offset=36, cutoff=0,
            threshold=0.7, scope=12; // XXX =- move this to LFO synth (modulator with DegreeToKey)
        var note, signal;
        var rq;
        var baseFreq, trig, timer, mul, add;
        mul = momentum.linlin(0, 1, 1850, 2350);
        add = momentum.linlin(0, 1, 2250, 2800);
        trig = momentum > 0.33; // high momentum causes sharp switch
        timer = Timer.kr(trig);
        baseFreq = TRand.kr(trig:Delay2.kr(Dust.kr(1)));
        cutoff = SelectX.kr(BinaryOpUGen('<', cutoff, 0) * 2,
            [ // Positive cutoff falls at the baseFreq range 500..5000
                TWChoose.kr((timer > 0.25) * trig,
                    [
                        LFNoise0.ar(baseFreq, mul, add),
                        LFNoise1.ar(baseFreq, mul, add),
                        LFNoise2.ar(baseFreq).clip2 * mul + add // quadratic interpolation can push beyond [-1..1]
                    ],
                    [0.1, 0.3, 0.6]
                ),
                5666 // zero or negative cutoff means constant
            ]
        ).poll;
        rq = SelectX.kr(BinaryOpUGen('==', cutoff, 5666) * 2,
            [ // If cutoff is variable, RQ depends on momentum.
                momentum.linlin(0, 1, 0.5, 0.1),
                0.1 // constant cutoff means constant RQ
            ]
        );
        note = SelectX.kr(BinaryOpUGen('<', az, threshold) * 2,
            [   // Go melodic above height threshold.
                DegreeToKey.kr(bufnum, az.linlin(threshold, 1, 0, scope), 12, 1, offset),
                az.linlin(0, threshold, (offset-6), offset) // bottom to middle change continuously
            ]
        );
        signal = Mix.fill(8, { LFSaw.ar((note + 0.1.rand2).midicps) * 0.05 });
        signal = RLPF.ar(RLPF.ar(signal, cutoff, rq), cutoff, rq, amp);
        outCodeFunc.value(
            signal, out, trigID, azimuth, distance, elevation,
            gate, attack, sustain, release, ca, cr, depth, elevClip
        );
    }).add;
};

spatialConf.keysValuesDo { |name, conf|
    // call SynthDef creation
    // `name` - name of spatial configuration
    // function - functionality of spatial configuration

    // synths based on ADSR
    makeSynthDefADSR.(name, {
        arg signal, out=0, trigID=80,
            azimuth= -0.5pi, distance=0.1, elevation=0,
            gate=1, attack=0.01, sustain=1, release=0.5, ca=3, cr= -3,
            depth=5, elevClip=0.01pi;
        var dist=distance.linlin(0, 2.sqrt, 0.01, depth);
        var elev=elevation.linlin(-0.5pi, 0.5pi, elevClip.neg, elevClip);
        var mix=distance.linexp(0, 2.sqrt, 0.1, 0.8);
        var room=distance.linexp(0, 2.sqrt, 0.2, 1);
        var w, x, y, z, r, s, t, u, v;
        // reverb, filter, envelope
        var output = RLPF.ar(
            FreeVerb.ar(Mix.ar(signal), mix, room, 0.2),
            distance.linlin(0, 2.sqrt, 10000, 1000),
            0.5
        ) * EnvGen.kr(
            Env.asr(attack, sustain, release, curve:[ca, cr]),
            gate: gate,
            doneAction: 2
        );
        // report (single channel after effects before spatialisation)
        SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(output));
        // spatialisation
        #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(output, azimuth, elev, dist);
        Out.ar(out,
            FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
                azimuth: \azim.kr(conf.azim),
                elevation: \elev.kr(conf.elev),
                distance: \dist.kr(conf.dist),
                maxDist: \maxDist.kr(conf.maxDist),
            )
        );
    });

    // percussive synths
    makeSynthDefPerc.(name, {
        arg signal, out=0, trigID=80,
            azimuth= -0.5pi, distance=0.1, elevation=0,
            gate=1, attack=0.01, release=0.5,
            depth=5, elevClip=0.01pi;
        var dist=distance.linlin(0, 2.sqrt, 0.01, depth);
        var elev=elevation.linlin(-0.5pi, 0.5pi, elevClip.neg, elevClip);
        var mix=distance.linexp(0, 2.sqrt, 0.1, 0.8);
        var room=distance.linexp(0, 2.sqrt, 0.2, 1);
        var w, x, y, z, r, s, t, u, v;
        // reverb, filter, envelope
        var output = RLPF.ar(
            FreeVerb.ar(Mix.ar(signal), mix, room, 0.2),
            distance.linlin(0, 2.sqrt, 10000, 1000),
            0.5
        ) * EnvGen.kr(
            Env.perc(attack, release), gate:gate
        );
        // report (single channel after effects before spatialisation)
        SendTrig.kr(Impulse.kr(30), trigID, Amplitude.kr(output));
        // spatialisation
        #w, x, y, z, r, s, t, u, v = FMHEncode1.ar(output, azimuth, elev, dist);
        Out.ar(out,
            FMHDecode1.ar1(w, x, y, z, r, s, t, u, v,
                azimuth: \azim.kr(conf.azim),
                elevation: \elev.kr(conf.elev),
                distance: \dist.kr(conf.dist),
                maxDist: \maxDist.kr(conf.maxDist),
            )
        );
    });
};

// MODULATORS
//
// XXX former \sr__k__sine
SynthDef(\ksine, {
    // arg out=0, lfreq=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    arg out=0, lfreq=1, phase=0, min= -1, max=1, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var mul = max.absdif(min) * 0.5;
    var add = min + mul;
    var ctl = env * SinOsc.ar(lfreq, phase, mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, ctl);
    Out.kr(out, ctl);
}).send(~scsynth);

// XXX former \sr__k__pulse
SynthDef(\kpulse, {
    arg out=0, lfreq=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var ctl = env * LFPulse.ar(lfreq, phase, mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, ctl);
    Out.kr(out, ctl);
}).send(~scsynth);

// XXX former \sr__k__saw
SynthDef(\ksaw, {
    arg out=0, lfreq=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var ctl = env * Saw.kr(lfreq, mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, ctl);
    Out.kr(out, ctl);
}).send(~scsynth);

// XXX \sr__k__tri
SynthDef(\ktri, {
    arg out=0, lfreq=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var ctl = env * LFTri.kr(lfreq, phase, mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, ctl);
    Out.kr(out, ctl);
}).send(~scsynth);

// XXX \sr__k__sawperc
SynthDef(\ksawprc, {
    arg out=0, lfreq=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var ctl = env * LFSaw.ar(lfreq, phase, mul, add).cubed.neg.clip;
    SendTrig.kr(Impulse.kr(30), trigID, ctl);
    Out.kr(out, ctl);
}).send(~scsynth);

// XXX former \sr__k__clipnoise
// clip noise
SynthDef(\klipnoise, {
    arg out=0, lfreq=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var ctl = env * LFDClipNoise.kr(lfreq, mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, ctl);
    Out.kr(out, ctl);
}).send(~scsynth);

// XXX former \sr__k__lfnoise0
// step noise
SynthDef(\klfno0, {
    // arg out=0, lfreq=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    arg out=0, lfreq=1, phase=0, min= -1, max=1, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var mul = max.absdif(min) * 0.5;
    var add = min + mul;
    var ctl = env * LFDNoise0.kr(lfreq, mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, ctl);
    Out.kr(out, ctl);
}).send(~scsynth);

// XXX former \sr__k__lfnoise1
SynthDef(\klfno1, {
    arg out=0, lfreq=1, phase=0, mul=1, add=0, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var ctl = env * LFNoise1.kr(lfreq, mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, ctl);
    Out.kr(out, ctl);
}).send(~scsynth);

// XXX former \sr__k__lfnoise2
SynthDef(\klfno2, {
    arg out=0, lfreq=1, phase=0, min= -1, max=1, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var mul = max.absdif(min) * 0.5;
    var add = min + mul;
    var ctl = env * LFNoise2.kr(lfreq).clip2 * mul + add;
    SendTrig.kr(Impulse.kr(30), trigID, ctl);
    Out.kr(out, ctl);
}).send(~scsynth);

// XXX former \sr__k__stepnoise
SynthDef(\kstepno, {
    arg out=0, lfreq=1, phase=0, min= -1, max=1, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var mul = max.absdif(min) * 0.5;
    var add = min + mul;
    var ctl = env * TWChoose.kr(
        Dust.ar(1),
        [LFNoise0.kr(lfreq, mul, add), LFNoise1.kr(lfreq, mul, add), LFNoise2.kr(lfreq).clip2 * mul + add],
        [0.2, 0.3, 0.5]
    );
    SendTrig.kr(Impulse.kr(30), trigID, ctl);
    Out.kr(out, ctl);
}).send(~scsynth);

// XXX former \sr__k__sinmod
SynthDef(\ksinmod, {
    arg out=0, lfreq=1, phase=0, mul=1, add=0, mod_mul=0.45, mod_add=0.55, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var ctl = env * SinOsc.kr(LFNoise0.kr(lfreq, mod_mul, mod_add), LFDClipNoise.kr(lfreq), mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, ctl);
    Out.kr(out, ctl);
}).send(~scsynth);

// XXX former \sr__k__sawmod
SynthDef(\ksawmod, {
    arg out=0, lfreq=1, mul=1, add=0, mod_mul=0.45, mod_add=0.55, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var ctl = env * Saw.kr(LFNoise0.kr(lfreq, mod_mul, mod_add), mul, add);
    SendTrig.kr(Impulse.kr(30), trigID, ctl);
    Out.kr(out, Saw.kr(lfreq, mul, add));
}).send(~scsynth);

// XXX former \sr__k__keyscale
SynthDef(\keyscale, {
    arg bufnum=0, val=0.5, idx=12, octave=12, detune=3, detuneDepth=0.04,
        out=0, min= -1, max=1, gate=1, att=1, rel=1, trigID=60;
    var env = EnvGen.kr(Env.adsr(att, 0.1, 1, rel, curve:[3, -3]), gate: gate, doneAction: 2);
    var mul = max.absdif(min) * 0.5;
    var add = min + mul;
    var note = (
        // `add` here is an offset and must be given in midi!
        DegreeToKey.kr(bufnum, val.linlin(0, 1, 0, idx), octave, mul, add)
        + LFNoise1.kr(detune, detuneDepth) // low freq detuning
    ).midicps;
    var ctl = env * note;
    SendTrig.kr(Impulse.kr(30), trigID, ctl);
    Out.kr(out, ctl);
}).send(~scsynth);


// AUXILIARY
//
SynthDef(\buffloop, { // continuous recording into buffer
    arg bufnum, busnum=0, volIn=0.8, loop=1, dur=1, gate=0;
    RecordBuf.ar(
        InFeedback.ar(busnum)
        * EnvGen.kr(
            Env.linen(0.1, dur-0.2, 0.1, volIn, \welch),
            gate: Impulse.kr(gate.reciprocal)
        ),
        bufnum, 0, volIn, 0, 1, loop, 1
    );
}).send(~scsynth);
)


// // TESTING
// a = Synth("buzz__a2", [\freq, 36.midicps, \amp, 0.5]);
// b = Synth("perc__a4", [\freq, 36.midicps]);
// c = Synth("buzz__a4", [\freq, 48.midicps, \amp, 0.5]);
// d = Synth("moog__a2", [\offset, 36, \amp, 0.5]);
// c.setn(\azim, #[-0.1, -0.2, -0.3, -0.4])
// b.setn(\maxDist, 3.5) // this also works: a.set(\maxDist, 2)
// a.set(\gate, 0)
// d.set(\gate, 0)
// c.set(\gate, 0)
//
// b = Buffer.sendCollection(s, FloatArray[0, 3, 7, 10])
// a = Synth(\buzz__a4, [\bufnum, b.bufnum, \freq, 12.midicps, \attack, 3, \momentum, 0.1]);
// a.set(\momentum, 0.8)
// a.set(\amp, 0.5)
// a.set(\freq, 432)
// (
// r = {
//     (0, 0.05..1).do { |i|
//         (12,18..72).do { |f|
//             [i, f].postln;
//             c.set(
//                 \momentum, i,
//                 \freq, f.midicps
//             );
//             0.5.wait;
//         };
//         "...".postln;
//         0.5.wait;
//     }
// }.fork
// )
// r.stop
// c.set(\gate, 0)


// TEST with nodeId
// (
// r = {
//     (380..800).do { |i|
//         i.postln;
//         s.sendMsg("/n_set", 1006, \freq, i);
//         0.5.wait;
//     }
// }.fork
// )
// r.stop

//
//
// // TEST: intro \gro2
// (
// k = Pbind(
//     \attack, Pseq([60, 0.5, Pxrand(#[1, 0.5, 0.3], 3)]),
//     \degree, Pseq([8, 11, Pxrand(#[0, 3, 7, 10]+8, 3)]),
//     \octave, 3,
//     \momentum, Pseq([0.5, Pwhite(0.0, 1.0)]).round(0.001),
//     \dur, Pseq([80, 2, Pxrand(#[10, 30, 5], 3)]),
//     \legato, Pseq([1, 0.5, Pxrand(#[1, 0.5, 0.3], 3)]),
//     \instrument, \pole__a2,
//     \bufnum, b.bufnum
// ).trace;
// f = k.play
// )
// f.stop
//
// // TEST: slow bass \prc2
// (
// p = Pbind(
//     \degree, Pseq(
//         [ Pseries(0, 3, 3), Pseq([ \ ], 3)], inf
//     ),
//     \octave, 3,
//     \dur, Pseq([1/8, 1/2, 1/8, 1/2, 1/2, 1/2], inf),
//     \instrument, \perc__a2,
//     \sustain, Pseq(
//         [ Pseq([0.5, Pwhite(0.2, 0.8)]), Pseq([ \ ], 4)], inf
//     ),
//     \amp, 0.8,
//     \bufnum, b.bufnum,
// ).trace;
// e = p.play(TempoClock(16/60))
// )
// e.stop
//
// (
// k = Pbind(
//     \degree, Pseq(
//         [ Pseries(0, 5, 4), Pseq([ \ ], 3)], inf
//     ),
//     \octave, 4,
//     \dur, Pseq([1/8, 1/2, 1/8, 1/2, 1/2, 1/2], inf),
//     \instrument, \perc__a4,
//     \sustain, Pseq(
//         [ Pseq([0.5, Pwhite(0.2, 0.8)]), Pseq([ \ ], 4)], inf
//     ),
//     \amp, 0.8,
//     \bufnum, b.bufnum,
// ).trace;
// f = k.play(TempoClock(32/60))
// )
// f.stop