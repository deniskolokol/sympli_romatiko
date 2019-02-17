(
var win = Window.new("test",
	Rect(0, 0, Window.screenBounds.width, Window.screenBounds.height),
	border:false
)
.background_(Color.red(alpha:0.1));
Window.screenBounds.height.postln;
// .background_(Color.grey(alpha:0.01));
win.front;

CmdPeriod.doOnce({
    win.close;
});
)