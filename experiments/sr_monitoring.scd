(
var monitor, message, spacer = "\n--------------------\n";
var textParticles, textAttractions, textForces, textSprings, textSkeleton, textTest;

var winMonitor = Window("Sympli Romatikó :: MONITOR", Rect(705, 1000, 360, Window.screenBounds.height));
var drawMonitorView = { |parent, width=350, height=130|
    var uv = UserView(winMonitor, width@height);
    uv.background = Color.new255(0, 0, 0, alpha:180);
    uv
};
var drawMonitorArea = { |parent, width, height|
    var st;
    width = width ?? parent.bounds.width;
    height = height ?? parent.bounds.height;
    st = StaticText(parent, width@height).focus(false);
    st.align = \topLeft;
    st.font = Font("Monaco", 12);
    st.stringColor = Color.white;
    st
};

winMonitor.addFlowLayout;
textParticles = drawMonitorArea.(drawMonitorView.(winMonitor, height:220));
textSprings = drawMonitorArea.(drawMonitorView.(winMonitor, height:220));
textAttractions = drawMonitorArea.(drawMonitorView.(winMonitor, height:250));
textForces = drawMonitorArea.(drawMonitorView.(winMonitor, height:65));
textSkeleton = drawMonitorArea.(drawMonitorView.(winMonitor, height:80));
textTest = drawMonitorArea.(drawMonitorView.(winMonitor, height:95));

// Monitoring.
monitor = {
    // TO-DO:
    // it should be possible to delete any particle (small [x] button near each nodeID)
    // and tear up any string (the same in strings)
    var springEnds = Array.fill(2, { nil });

    message = "Particles" ++ spacer;
    message = message ++ format(" %\tStar\n", star.identityHash);
    particles.keysValuesDo { |k, v|
        message = message ++ format(" %\t%\n", decodeParticle.(k), v.asString)
    };
    textParticles.string = message;

    message = "Springs" ++ spacer;
    springs.keysValuesDo { |k, v|
        springEnds = [v[0].identityHash, v[1].identityHash];
        if (v[0].class != TraerParticle) { springEnds[0] = v[0] };
        if (v[1].class != TraerParticle) { springEnds[1] = v[1] };
        message = message ++ format("% \t(%, %)\n", k, springEnds[0], springEnds[1])
    };
    message = message ++ (spacer ++ "Physics springs" ++ spacer);
    physics.springs.do { |g|
        message = message ++ format("% \t(%, %)\n", g.identityHash, g.a.identityHash, g.b.identityHash)
    };
    textSprings.string = message;

    message = "Skeletons" ++ spacer;
    skeleton.keysValuesDo { |k, v|
        message = message ++ format(" %:\t", k);
        v.keysValuesDo { |j, p|
            if (world.springSrcSkel.includes(j)) {
                message = message ++ format("% \t %\t", j, p.identityHash)
            }
        }
    };
    textSkeleton.string = message;

    message = "Attractions" ++ spacer;
    physics.attractions.do { |k|
        message = message ++ format("%\t%\n", decodeParticle.(k.a), decodeParticle.(k.b))
    };
    textAttractions.string = message;

    message = "Forces" ++ spacer;
    textForces.string = message ++ format("Gravity: %, %, %\nDrag: %\n",
        physics.gravity.x.round(0.001), physics.gravity.y.round(0.001), physics.gravity.z.round(0.001),
        physics.drag.round(0.001));
};

// This should be in the physics.tick loop
monitor.();

winMonitor.front;
CmdPeriod.doOnce({
    winMonitor.close;
});
)