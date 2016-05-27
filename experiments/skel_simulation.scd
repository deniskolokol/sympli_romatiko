(
var skelData, taskSkeletonJoint;
var index=0;
var tick=0.003;

postf("Reading skeleton simulation data\n");
skelData = File(
    PathName(thisProcess.nowExecutingPath).pathOnly +/+ "joints.log", "r"
).readAllString.interpret;

taskSkeletonJoint = Task({ |msg, time, addr, recvPort|
    var joint, x, y, z;
    inf.do {
        if (index == skelData.size) { index = 0 };
        joint = skelData[index][0];
        #x, y, z = skelData[index][1..];
        ~sendMessage.('/joint', [joint, 1, x, y, z]);
       index = index + 1;
        tick.wait;
    };
}).start;

CmdPeriod.doOnce({
    taskSkeletonJoint.stop;
});
)