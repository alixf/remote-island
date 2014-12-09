import h2d.Bitmap;
import h2d.Tile;

class AnimatedBitmap extends Bitmap
{
	public var tilesheet : Array<Tile>;
	public var indexes : Array<Int>;
	public var delay : Float;
	public var clock : Float;
	
	public function new(tilesheet : Array<Tile>, indexes : Array<Int>, delay : Float)
	{
		super();
		this.tilesheet = tilesheet;
		this.indexes = indexes;
		this.delay = delay;
		clock = 0.0;
		tile = tilesheet[indexes[0]];
	}
	
	public function update(dt : Float)
	{
		
		clock += dt * 0.016;
		while (clock >= indexes.length * delay)
			clock -= indexes.length * delay;
		tile = tilesheet[indexes[Math.floor(clock / delay)]];
	}
}