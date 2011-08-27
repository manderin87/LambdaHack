module Dungeon where

import Prelude hiding (floor)
import Control.Monad
import qualified System.Random as R

import Data.Binary
import Data.Map as M
import Data.List as L
import Data.Ratio
import Data.Maybe

import Geometry
import GeometryRnd
import Level
import Item
import Random
import qualified Terrain
import qualified ItemKind
import WorldLoc
import Tile  -- TODO: qualified

-- | The complete dungeon is a map from level names to levels.
-- We usually store all but the current level in this data structure.
newtype Dungeon = Dungeon (M.Map LevelId Level)
  deriving Show

instance Binary Dungeon where
  put (Dungeon dng) = put (M.elems dng)
  get = liftM dungeon get

-- | Create a dungeon from a list of levels.
dungeon :: [Level] -> Dungeon
dungeon = Dungeon . M.fromList . L.map (\ l -> (lname l, l))

-- | Extract a level from a dungeon.
getDungeonLevel :: LevelId -> Dungeon -> (Level, Dungeon)
getDungeonLevel ln (Dungeon dng) = (dng ! ln, Dungeon (M.delete ln dng))

-- | Put a level into a dungeon.
putDungeonLevel :: Level -> Dungeon -> Dungeon
putDungeonLevel lvl (Dungeon dng) = Dungeon (M.insert (lname lvl) lvl dng)

sizeDungeon :: Dungeon -> Int
sizeDungeon (Dungeon dng) = M.size dng

type Corridor = [(Y,X)]
type Room = Area

-- | Create a random room according to given parameters.
mkRoom :: Int ->      -- ^ border columns
          (Y,X) ->    -- ^ minimum size
          Area ->     -- ^ this is an area, not the room itself
          Rnd Room    -- ^ this is the upper-left and lower-right corner of the room
mkRoom bd (ym,xm) ((y0,x0),(y1,x1)) =
  do
    (ry0,rx0) <- locInArea ((y0 + bd,x0 + bd),(y1 - bd - ym + 1,x1 - bd - xm + 1))
    (ry1,rx1) <- locInArea ((ry0 + ym - 1,rx0 + xm - 1),(y1 - bd,x1 - bd))
    return ((ry0,rx0),(ry1,rx1))

-- | Create a no-room, i.e., a single corridor field.
mkNoRoom :: Int ->      -- ^ border columns
            Area ->     -- ^ this is an area, not the room itself
            Rnd Room    -- ^ this is the upper-left and lower-right corner of the room
mkNoRoom bd ((y0,x0),(y1,x1)) =
  do
    (ry,rx) <- locInArea ((y0 + bd,x0 + bd),(y1 - bd,x1 - bd))
    return ((ry,rx),(ry,rx))

data HV = Horiz | Vert
  deriving (Eq, Show, Bounded)

fromHV Horiz = True
fromHV Vert  = False

toHV True  = Horiz
toHV False = Vert

instance R.Random HV where
  randomR (a,b) g = case R.randomR (fromHV a, fromHV b) g of
                      (b, g') -> (toHV b, g')
  random g = R.randomR (minBound, maxBound) g

-- | Create a corridor, either horizontal or vertical, with
-- a possible intermediate part that is in the opposite direction.
mkCorridor :: HV -> (Loc,Loc) -> Area -> Rnd [(Y,X)] {- straight sections of the corridor -}
mkCorridor hv ((y0,x0),(y1,x1)) b =
  do
    (ry,rx) <- findLocInArea b (const True)
    -- (ry,rx) is intermediate point the path crosses
    -- hv decides whether we start in horizontal or vertical direction
    case hv of
      Horiz -> return [(y0,x0),(y0,rx),(y1,rx),(y1,x1)]
      Vert  -> return [(y0,x0),(ry,x0),(ry,x1),(y1,x1)]

-- | Try to connect two rooms with a corridor.
-- The condition passed to mkCorridor is tricky; there might not always
-- exist a suitable intermediate point if the rooms are allowed to be close
-- together ...
connectRooms :: Area -> Area -> Rnd [Loc]
connectRooms sa@((sy0,sx0),(sy1,sx1)) ta@((ty0,tx0),(ty1,tx1)) =
  do
    (sy,sx) <- locInArea sa
    (ty,tx) <- locInArea ta
    let xok = sx1 < tx0 - 3
    let xarea = normalizeArea ((sy,sx1+2),(ty,tx0-2))
    let yok = sy1 < ty0 - 3
    let yarea = normalizeArea ((sy1+2,sx),(ty0-2,tx))
    let xyarea = normalizeArea ((sy1+2,sx1+2),(ty0-2,tx0-2))
    (hv,area) <- if xok && yok then fmap (\ hv -> (hv,xyarea)) (binaryChoice Horiz Vert)
                 else if xok   then return (Horiz,xarea)
                               else return (Vert,yarea)
    mkCorridor hv ((sy,sx),(ty,tx)) area

digCorridors :: Corridor -> LMap
digCorridors (p1:p2:ps) =
  M.union corPos (digCorridors (p2:ps))
  where
    corLoc = fromTo p1 p2
    corPos = M.fromList $ L.zip corLoc (repeat $ newTile Terrain.floorDark)
digCorridors _ = M.empty

mergeCorridor :: (Tile, Tile) -> (Tile, Tile) -> (Tile, Tile)
mergeCorridor _ (Tile t l s is, u) | Terrain.isRock t    = (Tile Terrain.opening l s is, u)
mergeCorridor _ (Tile t l s is, u) | Terrain.isOpening t = (Tile Terrain.opening l s is, u)
mergeCorridor _ (Tile t l s is, u) | Terrain.isFloor t   = (Tile t l s is, u)
mergeCorridor _ (Tile _ l s is, u)                       = (Tile Terrain.floorDark l s is, u)

-- | Create a new tile.
newTile :: Terrain.Terrain -> (Tile, Tile)
newTile t = (Tile t Nothing Nothing [],
             Tile Terrain.unknown Nothing Nothing [])

-- | Create a new stairs tile.
newStairsTile :: Terrain.Terrain -> Maybe WorldLoc -> (Tile, Tile)
newStairsTile t l = (Tile t l Nothing [],
                     Tile Terrain.unknown Nothing Nothing [])

-- | Create a new door tile.
newDoorTile :: Terrain.Terrain -> Maybe Int -> (Tile, Tile)
newDoorTile t s = (Tile t Nothing s [],
                   Tile Terrain.unknown Nothing Nothing [])

-- | Create a level consisting of only one room. Optionally, insert some walls.
emptyRoom :: (Level -> Rnd (LMap -> LMap)) -> LevelConfig -> LevelId
             -> Rnd (Maybe (Maybe WorldLoc) -> Maybe (Maybe WorldLoc) -> Level,
                     Loc, Loc)
emptyRoom addRocksRnd cfg@(LevelConfig { levelSize = (sy,sx) }) nm =
  do
    let lmap = digRoom True ((1,1),(sy-1,sx-1)) (emptyLMap (sy,sx))
    let smap = M.fromList [ ((y,x),-100) | y <- [0..sy], x <- [0..sx] ]
    let lvl = Level nm emptyParty (sy,sx) emptyParty smap lmap ""
    -- locations of the stairs
    su <- findLoc lvl (const floor)
    sd <- findLoc lvl (\ l t -> floor t
                                && distance (su,l) > minStairsDistance cfg)
    is <- rollItems cfg lvl su
    addRocks <- addRocksRnd lvl
    let addItem lmap (l,it) =
          M.update (\ (t,r) -> Just (t { titems = it : titems t }, r)) l lmap
        flmap lu ld =
          addRocks $
          maybe id (\ l -> M.insert su (newStairsTile (Terrain.stairs True Up) l)) lu $
          maybe id (\ l -> M.insert sd (newStairsTile (Terrain.stairs True Down) l)) ld $
          (\lmap -> L.foldl' addItem lmap is) $
          lmap
        level lu ld = Level nm emptyParty (sy,sx) emptyParty smap (flmap lu ld) "bigroom"
    return (level, su, sd)

-- | For a bigroom level: Create a level consisting of only one, empty room.
bigRoom :: LevelConfig ->
           LevelId -> Rnd (Maybe (Maybe WorldLoc) -> Maybe (Maybe WorldLoc) -> Level, Loc, Loc)
bigRoom = emptyRoom (\ lvl -> return id)

-- | For a noiseroom level: Create a level consisting of only one room
-- with randomly distributed pillars.
noiseRoom :: LevelConfig ->
             LevelId -> Rnd (Maybe (Maybe WorldLoc) -> Maybe (Maybe WorldLoc) -> Level, Loc, Loc)
noiseRoom cfg =
  let addRocks lvl = do
        rs <- rollPillars cfg lvl
        let insertRock lmap l =
              case lmap `at` l of
                Tile t _ _ [] | Terrain.isFloor t -> M.insert l (newTile Terrain.rock) lmap
                _ -> lmap
        return $ \ lmap -> L.foldl' insertRock lmap rs
  in  emptyRoom addRocks cfg

data LevelConfig =
  LevelConfig {
    levelGrid         :: Rnd (Y,X),
    minRoomSize       :: Rnd (Y,X),
    darkRoomChance    :: Rnd Bool,
    border            :: Int,       -- must be at least 2!
    levelSize         :: (Y,X),     -- lower right point
    extraConnects     :: (Y,X) -> Int,
      -- relative to grid (in fact a range, because of duplicate connects)
    noRooms           :: (Y,X) -> Rnd Int,  -- range, relative to grid
    minStairsDistance :: Int,       -- must not be too large
    doorChance        :: Rnd Bool,
    doorOpenChance    :: Rnd Bool,
    doorSecretChance  :: Rnd Bool,
    doorSecretMax     :: Int,
    nrItems           :: Rnd Int,   -- range
    depth             :: Int        -- general indicator of difficulty
  }

normalLevelSize :: (Y,X)
normalLevelSize = (22,79)

defaultLevelConfig :: Int -> LevelConfig
defaultLevelConfig d =
  LevelConfig {
    levelGrid         = do
                          y <- randomR (2,4)
                          x <- randomR (3,5)
                          return (y,x),
    minRoomSize       = return (2,2),
    darkRoomChance    = chance $ 1%((22 - (2 * fromIntegral d)) `max` 2),
    border            = 2,
    levelSize         = normalLevelSize,
    extraConnects     = \ (y,x) -> (y*x) `div` 3,
    noRooms           = \ (y,x) -> randomR (0,(y*x) `div` 3),
    minStairsDistance = 676,
    doorChance        = chance $ 2%3,
    doorOpenChance    = chance $ 1%10,
    doorSecretChance  = chance $ 1%4,
    doorSecretMax     = 15,
    nrItems           = randomR (5,10),
    depth             = d
  }

largeLevelConfig :: Int -> LevelConfig
largeLevelConfig d =
  (defaultLevelConfig d) {
    levelGrid         = return (7,10),
    levelSize         = (77,231),
    extraConnects     = const 10
  }

-- | Create a "normal" dungeon level. Takes a configuration in order
-- to tweak all sorts of data.

{-
Leve is generated by an algorithm inspired by the original Rogue,
as follows:

  * The available area is divided into a 3 by 3 grid
    where each of the 9 grid cells has approximately the same size.

  * In each of the 9 grid cells one room is placed at a random location.
    The minimum size of a room is 2 by 2 floor tiles. A room is surrounded
    by walls, and the walls still have to fit into the assigned grid cells.

  * Rooms that are on horizontally or vertically adjacent grid cells
    may be connected by a corridor. Corridors consist of 3 segments of straight
    lines (either "horizontal, vertical, horizontal" or "vertical, horizontal,
    vertical"). They end in openings in the walls of the room they connect.
    It is possible that one or two of the 3 segments have length 0, such that
    the resulting corridor is L-shaped or even a single straight line.

  * Corridors are generated randomly in such a way that at least every room
    on the grid is connected, and a few more might be. It is not sufficient
    to always connect all adjacent rooms.

  * Stairs up and down are placed. Stairs are always located in two different
    randomly chosen rooms.
-}

rogueRoom :: LevelConfig ->
         LevelId ->
         Rnd (Maybe (Maybe WorldLoc) -> Maybe (Maybe WorldLoc) ->
              Level, Loc, Loc)
rogueRoom cfg nm =
  do
    lgrid    <- levelGrid cfg
    lminroom <- minRoomSize cfg
    let gs = grid lgrid ((0, 0), levelSize cfg)
    -- grid locations of "no-rooms"
    nrnr <- noRooms cfg lgrid
    nr   <- replicateM nrnr (do
                               let (y,x) = lgrid
                               yg <- randomR (0,y-1)
                               xg <- randomR (0,x-1)
                               return (yg,xg))
    rs0 <- mapM (\ (i,r) -> do
                              r' <- if i `elem` nr
                                      then mkNoRoom (border cfg) r
                                      else mkRoom (border cfg) lminroom r
                              return (i,r')) gs
    let rooms :: [(Loc, Loc)]
        rooms = L.map snd rs0
    dlrooms <- (mapM (\ r -> darkRoomChance cfg >>= \ c -> return (r, not c)) rooms) :: Rnd [((Loc, Loc), Bool)]
    let rs = M.fromList rs0
    connects <- connectGrid lgrid
    addedConnects <- replicateM (extraConnects cfg lgrid) (randomConnection lgrid)
    let allConnects = L.nub (addedConnects ++ connects)
    cs <- mapM
           (\ (p0,p1) -> do
                           let r0 = rs ! p0
                               r1 = rs ! p1
                           connectRooms r0 r1) allConnects
    let smap = M.fromList [ ((y,x),-100) | let (sy,sx) = levelSize cfg,
                                           y <- [0..sy], x <- [0..sx] ]
    let lrooms = L.foldr (\ (r, dl) m -> digRoom dl r m) M.empty dlrooms
        lcorridors = M.unions (L.map digCorridors cs)
        lrocks = emptyLMap (levelSize cfg)
        lmap = M.union (M.unionWith mergeCorridor lcorridors lrooms) lrocks
    let lvl = Level nm emptyParty (levelSize cfg) emptyParty smap lmap ""
    -- convert openings into doors
    dlmap <- fmap M.fromList . mapM
                (\ o@((y,x),(t,r)) ->
                  case t of
                    Tile t _ _ _ | Terrain.isOpening t ->
                      do
                        -- openings have a certain chance to be doors;
                        -- doors have a certain chance to be open; and
                        -- closed doors have a certain chance to be
                        -- secret
                        rb <- doorChance cfg
                        ro <- doorOpenChance cfg
                        rs <- if ro then return Nothing
                                    else do rsc <- doorSecretChance cfg
                                            fmap Just
                                                 (if rsc then randomR (doorSecretMax cfg `div` 2, doorSecretMax cfg)
                                                         else return 0)
                        if rb
                          then return ((y,x), newDoorTile (Terrain.door rs) rs)
                          else return o
                    _ -> return o) .
                M.toList $ lmap
    -- locations of the stairs
    su <- findLoc lvl (const floor)
    sd <- findLocTry 1000 lvl
            (const floor)
            (\ l t -> distance (su,l) > minStairsDistance cfg)
    -- determine number of items, items and locations for the items
    is <- rollItems cfg lvl su
    -- generate map and level from the data
    let meta = show allConnects
    return (\ lu ld ->
      let flmap = maybe id (\ l -> M.update (\ (t,r) -> Just $ newStairsTile (Terrain.stairs (light t) Up) l) su) lu $
                  maybe id (\ l -> M.update (\ (t,r) -> Just $ newStairsTile (Terrain.stairs (light t) Down) l) sd) ld $
                  L.foldr (\ (l,it) f -> M.update (\ (t,r) -> Just (t { titems = it : titems t }, r)) l . f) id is
                  dlmap
      in  Level nm emptyParty (levelSize cfg) emptyParty smap flmap meta, su, sd)

rollItems :: LevelConfig -> Level -> Loc -> Rnd [(Loc, Item)]
rollItems cfg lvl ploc =
  do
    nri <- nrItems cfg
    replicateM nri $
      do
        t <- newItem (depth cfg)
        l <- case ItemKind.jname (ItemKind.getIK (ikind t)) of
               "sword" ->
                 -- swords generated close to monsters; MUAHAHAHA
                 findLocTry 200 lvl
                   (const floor)
                   (\ l t -> distance (ploc, l) > 400)
               _ -> findLoc lvl (const floor)
        return (l,t)

rollPillars :: LevelConfig -> Level -> Rnd [Loc]
rollPillars cfg lvl =
  do
    nri <- 100 *~ nrItems cfg
    replicateM nri $
      do
        l <- findLoc lvl (const floor)
        return l

emptyLMap :: (Y, X) -> LMap
emptyLMap (my, mx) =
  M.fromList [ ((y, x), newTile Terrain.rock) | x <- [0..mx], y <- [0..my] ]

-- | If the room has size 1, it is at most a start of a corridor.
digRoom :: Bool -> Room -> LMap -> LMap
digRoom dl ((y0, x0), (y1, x1)) l
  | y0 == y1 && x0 == x1 = l
  | otherwise =
  let floorDL = if dl then Terrain.floorLight else Terrain.floorDark
      rm =
        [ ((y, x), newTile floorDL) | x <- [x0..x1], y <- [y0..y1] ]
        ++ [ ((y, x), newTile Terrain.rock)
           | x <- [x0-1, x1+1], y <- [y0..y1] ]
        ++ [ ((y, x), newTile Terrain.rock)
           | x <- [x0-1..x1+1], y <- [y0-1, y1+1] ]
  in M.unionWith const (M.fromList rm) l
