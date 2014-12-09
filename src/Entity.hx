import h2d.filter.DropShadow;
import h2d.Sprite;
import hxd.Key;
import h2d.Bitmap;
import hxd.Res;
import motion.Actuate;
import motion.easing.Linear;
import h2d.Text;

class Entity extends Sprite
{
	var game : Game;
	var moving : Bool;
	public var initialMovePoints = 4;
	public var initialHP = 10;
	public var movePoints = 4;
	public var attackRange = 6;
	public var viewRadius = 5;
	public var moveDelay = 0.05;
	public var team = 0;
	public var attackedThisTurn = false;
	public var movedThisTurn = false;
	public var info = "";
	public var hp = 10;
	public var firePower = 5;
	public var abmp : AnimatedBitmap;
	public var type = 0;
	
	var bubble : Sprite;
	var text : Text;
	var background : Bitmap;
	var quote : Bitmap;
	
	public function new(game : Game)
	{
		super();
		this.game = game;
		
		bubble = new Sprite();
		bubble.scaleX = 0.0;
		bubble.scaleY = 0.0;
		
		text = new Text(game.font);
		background = new Bitmap(game.tilesheet[52]);
		quote = new Bitmap(game.tilesheet[53]);
		text.textColor = 0x000000;
		text.x = 10;
		background.x = text.x;
		quote.x = background.x;
		bubble.addChild(background);
		bubble.addChild(quote);
		bubble.addChild(text);
		this.addChild(bubble);

	}
	
	public function resetTurn()
	{
		attackedThisTurn = false;
		movedThisTurn = false;
		movePoints = initialMovePoints;
		
		if (hp > 0)
			hp = Math.floor(Math.min(initialHP, hp + 1));
	}
	
	public function startAction(action : Game.Action)
	{
		switch(action)
		{
		case Game.Action.move :
			abmp.indexes = [type * 10 + 2, type * 10 + 3];
		default :
		}
	}
	
	public function endAction(action : Game.Action)
	{
		switch(action)
		{
		case Game.Action.move :
			abmp.indexes = [type * 10 + 0, type * 10 + 1];
			movedThisTurn = true;
		case Game.Action.attack :
			abmp.indexes = [type * 10 + 4, type * 10 + 5];
			abmp.delay = 0.15;
			Actuate.timer(1).onComplete(function()
			{
				abmp.indexes = [type * 10 + 0, type * 10 + 1];
				abmp.delay = 0.5;
			});
			attackedThisTurn = true;
			movePoints = 0;
			
			
		default :
		}
	}
	
	public function cancelAction(action : Game.Action)
	{
		switch(action)
		{
		case Game.Action.move :
		default :
		}
	}
	
	public function canMove()
	{
		return movePoints > 0 && !movedThisTurn;
	}
	
	public function canAttack()
	{
		return !attackedThisTurn;
	}
	
	public function canGiveInfo()
	{
		return info != "";
	}
	
	public var gridX(default, set) : Int = 0;
	public var gridY(default, set) : Int = 0;
	public function set_gridX(v : Int)
	{
		this.game.map[gridX][gridY].entity = null;
		this.gridX = v;
		this.game.map[gridX][gridY].entity = this;
		
		Actuate.tween(this, moveDelay, {x : Game.tileSize * this.gridX}).ease(Linear.easeNone);
		
		//this.x = Game.tileSize * this.gridX;
		return v;
	}
	public function set_gridY(v : Int)
	{
		this.game.map[gridX][gridY].entity = null;
		this.gridY = v;
		this.game.map[gridX][gridY].entity = this;
		
		Actuate.tween(this, moveDelay, {y : Game.tileSize * this.gridY}).ease(Linear.easeNone);
		
		//this.y = Game.tileSize * this.gridY;
		return v;
	}
	
	public function moveOnGrid(path : Array<{x : Int, y : Int}>)
	{	
		function nextStep()
		{
			path.shift();
			if (path.length > 0)
			{
				var puf = new AnimatedBitmap(game.charsheet, [90, 91, 92, 93], 0.25);
				puf.x = gridX * Game.tileSize;
				puf.y = gridY * Game.tileSize;
				game.fxLayer.addChild(puf);
				Actuate.timer(1).onComplete(function() { game.fxLayer.removeChild(puf); } );
				
				gridX = path[0].x;
				gridY = path[0].y;
				Actuate.timer(moveDelay).onComplete(nextStep);
				game.updateVisibility();
			}
		}
		
		movePoints -= path.length - 1;
		nextStep();
	}
	
	public function update(dt : Float)
	{
		this.x = x;
		
		for (drawable in childs)
		{
			var abmp = Std.instance(drawable, AnimatedBitmap);
			if(abmp != null)
				abmp.update(dt);
		}
	}
	
	public function showInfo(time : Float)
	{
		showMessage(this.info + "\nHP : " + hp + "\nAttack : " + firePower + "\nRange : "+attackRange, time);
	}
	
	public function showMessage(message : String, ?time : Null<Float> = null)
	{
		text.text = message;
		text.y = -text.textHeight-1;
		background.scaleX = text.textWidth / 16;
		background.scaleY = text.textHeight / 16;
		background.y = text.y-3;
		quote.y = background.y + background.scaleY * 16;
		
		if (this.x + text.textWidth + 10 > game.s2d.width)
			text.x = -text.textWidth+40;
		else
			text.x = 10;
		background.x = text.x;
		
		Actuate.tween(bubble, 0.25, { scaleX : 1.0, scaleY : 1.0 } );
		
		if(time != null)
			Actuate.timer(time).onComplete(function() { hideMessage(); } );
	}
	
	public function hideMessage()
	{
		Actuate.tween(bubble, 0.25, {scaleX : 0.0, scaleY : 0.0});
	}
	
	public function attack(target : Entity)
	{
		var fx = new AnimatedBitmap(game.charsheet, [94, 95, 96, 97, 98], 0.1);
		fx.x = target.gridX * Game.tileSize;
		fx.y = target.gridY * Game.tileSize;
		game.fxLayer.addChild(fx);
		Actuate.timer(1).onComplete(function() { game.fxLayer.removeChild(fx); } );
		
		game.attackSound.play();
				
		target.hp -= firePower;
		if (target.hp <= 0)
		{
			target.abmp.indexes = [target.type*10+6];
			game.map[target.gridX][target.gridY].entity = null;
		}
	}
}