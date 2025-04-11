# Goal
The goal of this project was to develop a hybrid implementation of an optimized non-player character (NPC). This NPC would exist solely on the client and have its position managed by the server. Additionally, the pathfinding, which requires expensive calculations, would be minimized through a render system. 

## Prerequisites:
[Knit Framework](https://github.com/Sleitnick/Knit)] - Used the Silo object to define transitions in between behavioral states. Also used such framework to make a single Script (server) and LocalScript (client) to control all of the components of this game via Services and Controllers. 

## Resources
[NPC Client](https://www.youtube.com/watch?v=JyMxrcqEzu8&t=974s&pp=ygUPbnBjIHBhdGhmaW5kaW5n) What this NPC system is based off on. The servers only maintain position, while the client contains the actual NPC. 

## Optimizations
[Avoidance of physics calcualtions](#Physics)
[Render system](#Render)
[Client-sided](#Client)


# Physics
Arguably, this can be considered overcall, but primarily, the NPCs in this game lack a Humanoid object. This is for the sole purpose of eliminating physics. In general, the NPCs are managed via an anchored block where the server controls the animation. 

# Render
Two render systems exist (both on the server and client). On the client, if the NPC is away from the player within a certain distance, the NPC is simply moved out of the workspace (where assets are rendered visible to players) into ReplicatedStorage (where unrendered assets are usually stored). On the server, this render condition will determine whether enemy should use Pathfinding or simple teleportation to accomplish such. 

