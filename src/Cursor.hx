import h2d.Sprite;
import h2d.Bitmap;
import hxd.Key;
import motion.Actuate;

@:enum abstract CursorType(Int)
{
	var selection = 0;
	var action = 1;
	var move = 2;
	var attack = 3;
}

class Cursor extends Sprite
{
	var game : Game;
	var cursor : Bitmap;
	var cursorClock : Float;
	public var selection : Null<Entity>; 
	var wheelActions : Array<Bitmap>;
	var wheel : Sprite;
	var wheelOpened : Bool;
	var selectedAction : Game.Action;
	public var type = CursorType.selection;
	
	var moveCenterX = 0;
	var moveCenterY = 0;
	var moveRadius = 0;
	
	var path = new Array<{x : Int, y : Int}>();
	
	public function new(game : Game)
	{
		super();
		this.game = game;
		
		addChild(new Bitmap(hxd.Res.cursor.toTile()));
		
		wheelActions = [
			new Bitmap(hxd.Res.wheelLeft.toTile()),
			new Bitmap(hxd.Res.wheelUp.toTile()),
			new Bitmap(hxd.Res.wheelRight.toTile()),
			new Bitmap(hxd.Res.wheelDown.toTile()),
		];
		
		wheel = new Sprite();
		for (option in wheelActions)
		{
			wheel.addChild(option);
			option.x = -option.tile.width/2;
			option.y = -option.tile.height / 2;
		}
		addChild(wheel);
		wheel.scale(0);
		wheel.x = hxd.Res.cursor.toTile().width / 2;
		wheel.y = hxd.Res.cursor.toTile().height / 2;
		wheelOpened = false;
		
		cursorClock = 0.0;
		selectedAction = Game.Action.none;
	}
	
	public var gridX(default, set) : Int = 0;
	public var gridY(default, set) : Int = 0;
	public function set_gridX(v : Int)
	{
		this.gridX = v;
		
		this.x = Game.tileSize * this.gridX;
		return v;
	}
	public function set_gridY(v : Int)
	{
		this.gridY = v;
		this.y = Game.tileSize * this.gridY;
		return v;
	}
	
	public function hide()
	{
		wheelOpened = false;
		Actuate.tween(wheel, 0.25, { scaleX : 0, scaleY : 0 } );
	}
	
	public function canGo(x: Int, y : Int)
	{
		if (type == CursorType.move || type == CursorType.attack)
		{
			function compare(x : Int, y : Int, a : { x : Int, y : Int } )
			{
				return x == a.x && y == a.y;
			}
			
			if (Math.abs((moveCenterX - x)) + Math.abs((moveCenterY - y)) <= moveRadius
				&& (type != CursorType.move || game.map[x][y].entity == null)
				&& (type != CursorType.move || game.map[x][y].practicable)
				&& (type != CursorType.move || path.length <= moveRadius || Lambda.exists(path, compare.bind(x, y))))
				return true;
			return false;
		}
		return true;
	}
	
	private function resetOptions()
	{
		for (option in wheelActions)
		{
			option.x = -option.tile.width / 2;
			option.y = -option.tile.height / 2;
		}
		selectedAction = Game.Action.none;
	}
	
	public function update(dt : Float)
	{
		// Move cursor
		cursorClock += dt * 0.016;
		if (cursorClock > 0.15 && type != CursorType.action)
		{
			var noAction = false;
			if (Key.isDown(Key.LEFT))
			{
				if(canGo(gridX-1, gridY))
					this.gridX = Math.floor(Math.max(0, gridX - 1));
				else
					game.nopeSound.play();
			}
			else if (Key.isDown(Key.RIGHT))
			{
				if(canGo(gridX+1, gridY))
					this.gridX = Math.floor(Math.min(Game.terrainWidth-1, gridX+1));
				else
					game.nopeSound.play();
			}
			else if (Key.isDown(Key.UP))
			{
				if(canGo(gridX, gridY-1))
					this.gridY = Math.floor(Math.max(0, gridY-1));
				else
					game.nopeSound.play();
			}
			else if (Key.isDown(Key.DOWN))
			{
				if(canGo(gridX, gridY+1))
					this.gridY = Math.floor(Math.min(Game.terrainHeight-1, gridY+1));
				else
					game.nopeSound.play();
			}
			else
				noAction = true;
				
			if (!noAction)
			{
				cursorClock = 0.0;
				
				if (type == CursorType.move)
				{
					function compare(x : Int, y : Int, a : { x : Int, y : Int } )
					{
						return x == a.x && y == a.y;
					}
					var prevPos = Lambda.find(path, compare.bind(gridX, gridY));
					if (prevPos != null)
					{
						game.hidePath(path);
						path = path.slice(0, Lambda.indexOf(path, prevPos)+1);
						game.showPath(path);
					}
					else
					{
						path.push({ x : gridX, y : gridY });
						game.showPath(path);
					}					
				}
			}
		}
		
		if (type == CursorType.move)
		{
			if(Key.isPressed(Key.SPACE))
			{
				var target = game.map[gridX][gridY].entity;
				if (target == null)
				{
					selection.moveOnGrid(path);
					game.hideOverTile();
					type = CursorType.selection;
					selection.endAction(selectedAction);
					selection = null;
					selectedAction = Game.Action.none;
					resetOptions();
					path = [];
					
					game.okSound.play();
				}
				game.nopeSound.play();
			}
			if (Key.isPressed(Key.ESCAPE))
			{
				game.hideOverTile();
				type = CursorType.selection;
				selection.cancelAction(selectedAction);
				selection = null;
				selectedAction = Game.Action.none;
				resetOptions();
				path = [];
				game.cancelSound.play();
			}
		}
		else if (type == CursorType.attack)
		{
			if (Key.isPressed(Key.SPACE))
			{
				var target = game.map[gridX][gridY].entity;
				if (target != null)
				{
					game.hideOverTile();
					type = CursorType.selection;
					selection.endAction(selectedAction);
					selection.attack(target);
					selection = null;
					selectedAction = Game.Action.none;
					resetOptions();	
					game.okSound.play();
				}
			}
			if (Key.isPressed(Key.ESCAPE))
			{
				game.hideOverTile();
				type = CursorType.selection;
				selection.cancelAction(selectedAction);
				selection = null;
				selectedAction = Game.Action.none;
				resetOptions();
				game.cancelSound.play();
			}
		}
		else if (type == CursorType.action)
		{
			var offset = 5;
			if (Key.isPressed(Key.LEFT) && selection.canAttack())
			{
				resetOptions();
				selectedAction = Game.Action.attack;
				wheel.childs[0].x -=  offset;
				game.okSound.play();
			}
			else if (Key.isPressed(Key.UP) && selection.canGiveInfo())
			{
				resetOptions();
				selectedAction = Game.Action.info;
				wheel.childs[1].y -= offset;
				game.okSound.play();
			}
			else if (Key.isPressed(Key.RIGHT) && selection.canMove())
			{
				resetOptions();
				selectedAction = Game.Action.move;
				wheel.childs[2].x += offset;
				game.okSound.play();
			}
			else if (Key.isPressed(Key.DOWN) && false)
			{
				resetOptions();
				selectedAction = Game.Action.wait;
				wheel.childs[3].y += offset;
				game.okSound.play();
			}
			if (Key.isPressed(Key.ESCAPE))
			{
				type = CursorType.selection;
				selectedAction = Game.Action.none;
				resetOptions();
				hide();
				game.cancelSound.play();
			}
			else if (Key.isPressed(Key.SPACE))
			{
				if (selectedAction != Game.Action.none)
				{
					if (selectedAction == Game.Action.move)
					{
						type = CursorType.move;
						moveCenterX = gridX;
						moveCenterY = gridY;
						moveRadius = selection.movePoints;
						game.showMoveRadius(moveCenterX, moveCenterY, moveRadius);
						path = [ { x : gridX, y : gridY } ];
					}
					else if (selectedAction == Game.Action.attack)
					{
						type = CursorType.attack;
						moveCenterX = gridX;
						moveCenterY = gridY;
						moveRadius = selection.attackRange;
						game.showAttackRadius(moveCenterX, moveCenterY, moveRadius);
					}
					else if (selectedAction == Game.Action.info)
					{						
						type = CursorType.selection;
						selection.showInfo(5);
						selectedAction = Game.Action.none;
						resetOptions();
					}
					hide();
					selection.startAction(selectedAction);
					game.okSound.play();
				}
			}
		}
		else if(type == CursorType.selection)
		{
			if (Key.isPressed(Key.SPACE))
			{
				selection = game.map[Math.floor(this.x / Game.tileSize)][Math.floor(this.y / Game.tileSize)].entity;
				
				if (selection != null)
				{
					type = CursorType.action;
					Actuate.tween(wheel, 0.25, { scaleX : 1, scaleY : 1 } );
					for (action in  wheelActions)
						action.alpha = 0.5;
					if(selection.team == 0 && selection.canAttack())
						wheelActions[0].alpha = 1.0;
					if(selection.team == 0 && selection.canMove())
						wheelActions[2].alpha = 1.0;
					if(selection.canGiveInfo())
						wheelActions[1].alpha = 1.0;
					game.okSound.play();
				}
			}			
		}
	}
}