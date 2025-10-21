extends Node

## An event bus for housing signals in the project that can be emitted from 
## anywhere without hierarchy dependency
## Behaves like a singleton (see Project Settings -> Globals)

@warning_ignore_start("unused_signal") # Signals are used outside this file

#region App stuff
# Configuration for app was updated
signal app_configured()
#endregion

#region Reward pool
signal rewards_modified
#endregion

#region Machine stuff
# Controller tells machine that no rewards are a in it (just sound)
signal machine_empty() # Notify that the reward pool is empty

# Controller tells machine it was kicked (just sound)
signal machine_kicked() # Notify the machine it was kicked

# Controller tells machine to crank
# Controller tells machine what reward was dropped
signal machine_cranked(reward : Reward) # Notify machine that this reward is ready to drop

# Machine tells controller that reward has been shown
signal reward_presented() # Notify the controller that the machine has shown the reward

# Machine was loaded with new rewards
#signal rewards_added(reward: Array) # Tell the machine it was loaded with rewards
#signal machine_loaded() # Notify the controller that rewards
#endregion
