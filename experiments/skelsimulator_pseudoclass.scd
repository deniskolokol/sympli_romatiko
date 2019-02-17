(// SKELETON SIMULATION
~skelSimulator = {
    |dataFile|
    var data=nil;
    var loadData = {
        postf("Reading skeleton simulation data from:\n%\n", dataFile);
        data = File(dataFile, "r").readAllString.interpret;
    };
    (
        inertia: 1,
        free: { |self|
            data = nil;
            self = nil
        },
        proc: { |self|
            Task({
                var i=0, coords;
                inf.do {
                    if (i == data.size) {i = 0};
                    coords = data[i][1..];
                    ~sendMessage.(\joint, [data[i][0], 1] ++ coords);
                    i = i + 1;
                    self.inertia.wait;
                }
            });
        },
        run: { |self|
            if (data.isNil) {loadData.value};
            self.proc.start
        },
        halt: { |self| self.proc.stop}
    )
};
)

m = ~skelSimulator.value("/Users/deko/Documents/dev_music/sympli_romatiko/experiments/joints.log");

m.run;
m.inertia=3;
m.proc.
m.halt;
m.free;
