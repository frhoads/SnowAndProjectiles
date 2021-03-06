//
//  MyScene.m
//  SpriteKitSimpleGame
//
//  Created by Main Account on 9/4/13.
//  Copyright (c) 2013 Razeware LLC. All rights reserved.
//

#import "MyScene.h"
#import "GameOverScene.h"

static const uint32_t projectileCategory     =  0x1 << 0;
static const uint32_t monsterCategory        =  0x1 << 1;


// 1
@interface MyScene () <SKPhysicsContactDelegate, UIGestureRecognizerDelegate>
{
    UIPanGestureRecognizer* panGestureRecognizer;
    CGPoint projectileSpawnPoint;
}
@property (nonatomic) SKSpriteNode * player;
@property (nonatomic) NSTimeInterval lastSpawnTimeInterval;
@property (nonatomic) NSTimeInterval lastUpdateTimeInterval;
@property (nonatomic) int monstersDestroyed;
@property (nonatomic) SKSpriteNode* projectile;

@end

static inline CGPoint rwAdd(CGPoint a, CGPoint b) {
    return CGPointMake(a.x + b.x, a.y + b.y);
}
 
static inline CGPoint rwSub(CGPoint a, CGPoint b) {
    return CGPointMake(a.x - b.x, a.y - b.y);
}
 
static inline CGPoint rwMult(CGPoint a, float b) {
    return CGPointMake(a.x * b, a.y * b);
}
 
static inline float rwLength(CGPoint a) {
    return sqrtf(a.x * a.x + a.y * a.y);
}

static inline CGPoint rwInvert(CGPoint point)
{
    return CGPointMake(-point.x, -point.y);
}

// Makes a vector have a length of 1
static inline CGPoint rwNormalize(CGPoint a) {
    float length = rwLength(a);
    return CGPointMake(a.x / length, a.y / length);
}

@implementation MyScene
 
-(id)initWithSize:(CGSize)size {    
    if (self = [super initWithSize:size]) {
 
        // 1) Loading the background
        _background = [SKSpriteNode spriteNodeWithImageNamed:@"bg.jpg"];
        [_background setName:@"background"];
        [_background setAnchorPoint:CGPointZero];
        [self addChild:_background];
        
        // 2
        NSLog(@"Size: %@", NSStringFromCGSize(size));
 
        // 3
       // self.backgroundColor = [SKColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
 
        // 4
        self.player = [SKSpriteNode spriteNodeWithImageNamed:@"hero"];
        self.player.position = CGPointMake(self.player.size.width*2, self.frame.size.height*2/5);
        [self addChild:self.player];
        
        projectileSpawnPoint = CGPointMake(self.player.size.width*2, self.frame.size.height*2/5+self.player.size.height/2);
        
        
        NSString *snowPath =
        [[NSBundle mainBundle] pathForResource:@"backgroundSnow" ofType:@"sks"];
        SKEmitterNode* snowEmitter = [NSKeyedUnarchiver unarchiveObjectWithFile:snowPath];
        snowEmitter.position = CGPointMake(self.frame.size.width/2, self.frame.size.height+10);
        [_background addChild:snowEmitter];
        
        [self spawnProjectile];
        
        self.physicsWorld.gravity = CGVectorMake(0,-5);
        self.physicsWorld.contactDelegate = self;
 
    }
    return self;
}

-(void)spawnProjectile
{
    self.projectile = [SKSpriteNode spriteNodeWithImageNamed:@"snowball"];
    self.projectile.physicsBody.affectedByGravity = NO;
    self.projectile.position = projectileSpawnPoint;
    self.projectile.alpha = 1;
    [self.projectile setName:movableNodeName];
    [self addChild:self.projectile];
   // [self.projectile runAction:[SKAction fadeInWithDuration:1]];

}

- (void)didMoveToView:(SKView *)view {
    UIPanGestureRecognizer *gestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanFrom:)];
    [[self view] addGestureRecognizer:gestureRecognizer];
    gestureRecognizer.delegate = self;
}

- (void)handlePanFrom:(UIPanGestureRecognizer *)recognizer {
	if(self.projectile.alpha == 1 && self.projectile.physicsBody.affectedByGravity == NO)
    {
        CGPoint touchLocation = [recognizer locationInView:recognizer.view];
        touchLocation = [self convertPointFromView:touchLocation];
        if (recognizer.state == UIGestureRecognizerStateBegan) {
            [self selectNodeForTouch:touchLocation];
        } else if (recognizer.state == UIGestureRecognizerStateChanged) {
            CGPoint translation = [recognizer translationInView:recognizer.view];
            translation = CGPointMake(translation.x, -translation.y);
            [self panForTranslation:translation fromStartPoint:touchLocation];
            [recognizer setTranslation:CGPointZero inView:recognizer.view];
            
        } else if (recognizer.state == UIGestureRecognizerStateEnded) {
            
            if ([[_selectedNode name] isEqualToString:movableNodeName]) {
                
                CGPoint location = self.projectile.position;
                CGPoint offset = rwSub(location, projectileSpawnPoint);
                
                // 4 - Bail out if you are shooting down or backwards
                if (offset.x >= 0) return;
                
                // 5 - OK to add now - we've double checked position
                
                
                // 6 - Get the direction of where to shoot
                CGPoint direction = rwNormalize(offset);
                CGPoint launchDirection = rwInvert(direction);
                float force = rwLength(offset);
                CGPoint multiplied = rwMult(launchDirection, force/3);
                CGVector launcher = CGVectorMake(multiplied.x, multiplied.y);
                
                self.projectile.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:self.projectile.size.width/2];
                self.projectile.physicsBody.dynamic = YES;
                self.projectile.physicsBody.categoryBitMask = projectileCategory;
                self.projectile.physicsBody.contactTestBitMask = monsterCategory;
                self.projectile.physicsBody.collisionBitMask = 0;
                self.projectile.physicsBody.usesPreciseCollisionDetection = YES;
                
                self.projectile.physicsBody.affectedByGravity = YES;
                [self.projectile.physicsBody applyImpulse:launcher];
                
            }
        }
    }
}

- (void)panForTranslation:(CGPoint)translation fromStartPoint:(CGPoint)point
{
    if([self isWithinSlingshotDragArea:point])
    {
        CGPoint position = self.projectile.position;
        CGPoint newPosition = CGPointMake(position.x + translation.x, position.y + translation.y);
        if([self isWithinSlingshotDragArea:newPosition]) {
            [self.projectile setPosition:newPosition];
        }
    }
}

- (void)selectNodeForTouch:(CGPoint)touchLocation {
    if([self isWithinSlingshotDragArea:touchLocation])
    {
        SKAction *sequence = [SKAction sequence:@[[SKAction rotateByAngle:degToRad(-4.0f) duration:0.1],
                                                  [SKAction rotateByAngle:0.0 duration:0.1],
                                                  [SKAction rotateByAngle:degToRad(4.0f) duration:0.1]]];
    [self.projectile runAction:[SKAction repeatActionForever:sequence]];
        _selectedNode = self.projectile;
    }
}

-(BOOL)isWithinSlingshotDragArea:(CGPoint)point
{
    if(point.x < projectileSpawnPoint.x)
    {
        return YES;
    }
    return NO;
}

float degToRad(float degree) {
	return degree / 180.0f * M_PI;
}
- (void)addMonster {
 
    // Create sprite
    SKSpriteNode * monster = [SKSpriteNode spriteNodeWithImageNamed:@"snowman"];
    monster.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:monster.size]; // 1
    monster.physicsBody.dynamic = YES; // 2
    monster.physicsBody.categoryBitMask = monsterCategory; // 3
    monster.physicsBody.contactTestBitMask = projectileCategory; // 4
    monster.physicsBody.collisionBitMask = 0; // 5
    monster.physicsBody.affectedByGravity = NO;

    // Determine where to spawn the monster along the Y axis
    monster.position = CGPointMake(self.frame.size.width - monster.size.width/2, self.frame.size.height/2);
    //monster.position = CGPointMake(190, 0);
    //monster.position = CGPointMake(0, 0);
    NSValue *value = [NSValue valueWithCGPoint:monster.position];
    
    [self addChild:monster];
 
    // Create the actions
    SKAction * actionMove = [SKAction followPath:[self generateCurvePath:@[value]] asOffset:YES orientToPath:NO duration:5.0];
                             
    SKAction * actionMoveDone = [SKAction removeFromParent];
//    SKAction * loseAction = [SKAction runBlock:^{
//        SKTransition *reveal = [SKTransition flipHorizontalWithDuration:0.5];
//        SKScene * gameOverScene = [[GameOverScene alloc] initWithSize:self.size won:NO];
//        [self.view presentScene:gameOverScene transition: reveal];
//    }];
    [monster runAction:[SKAction sequence:@[actionMove/*, loseAction*/, actionMoveDone]]];
 
}

-(CGMutablePathRef)generateCurvePath:(NSArray*)coordinates
    {
        CGMutablePathRef path = CGPathCreateMutable();
        CGPathMoveToPoint(path, Nil, 0, 0);
        CGPathAddCurveToPoint(path, nil, -100, 100, -200, -100, -560, -50);
       // CGPathAddLineToPoint(path, nil, -500, -150);
        
        return path;
        
    }

- (void)updateWithTimeSinceLastUpdate:(CFTimeInterval)timeSinceLast {
 
    self.lastSpawnTimeInterval += timeSinceLast;
    if (self.lastSpawnTimeInterval > 1) {
        self.lastSpawnTimeInterval = 0;
        [self addMonster];
        
        if(self.projectile.position.x > self.size.width || -self.projectile.position.y > self.size.height)
        {
            [self.projectile removeFromParent];
        }
        
        if(![self.children containsObject:self.projectile])
        {
            [self spawnProjectile];
        }
    }
}

- (void)update:(NSTimeInterval)currentTime {
    // Handle time delta.
    // If we drop below 60fps, we still want everything to move the same distance.
    CFTimeInterval timeSinceLast = currentTime - self.lastUpdateTimeInterval;
    self.lastUpdateTimeInterval = currentTime;
    if (timeSinceLast > 1) { // more than a second since last update
        timeSinceLast = 1.0 / 60.0;
        self.lastUpdateTimeInterval = currentTime;
    }
    
    [self updateWithTimeSinceLastUpdate:timeSinceLast];
 
}

- (void)projectile:(SKSpriteNode *)projectile didCollideWithMonster:(SKSpriteNode *)monster {
    NSLog(@"Hit");
    NSString *path = [[NSBundle mainBundle] pathForResource:@"SnowSplosion" ofType:@"sks"];
    SKEmitterNode* explosion = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    
    [monster addChild:explosion];
    monster.physicsBody.collisionBitMask = 0;
    monster.physicsBody.contactTestBitMask = 0;
    SKAction* fadeOut = [SKAction fadeOutWithDuration:.5];
    SKAction* remove = [SKAction removeFromParent];
    [monster runAction:[SKAction sequence:@[fadeOut, remove]]];
    
    [projectile removeFromParent];
    
    self.monstersDestroyed++;
    [self runAction:[SKAction playSoundFileNamed:@"plop.mp3" waitForCompletion:NO]];
   
}

- (void)didBeginContact:(SKPhysicsContact *)contact
{
    // 1
    SKPhysicsBody *firstBody, *secondBody;
 
    if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask)
    {
        firstBody = contact.bodyA;
        secondBody = contact.bodyB;
    }
    else
    {
        firstBody = contact.bodyB;
        secondBody = contact.bodyA;
    }
 
    // 2
    if (firstBody.categoryBitMask == projectileCategory &&
        secondBody.categoryBitMask == monsterCategory)
    {
        [self projectile:(SKSpriteNode *) firstBody.node didCollideWithMonster:(SKSpriteNode *) secondBody.node];
    }
}

@end
