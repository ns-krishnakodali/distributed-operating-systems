# Reddit Clone

A Reddit clone simulator developed in `gleam` leevraging the actor model.

## Input Format

To run the program, use the following format:

```text
num_nodes num_seconds
```

Where:

- `num_nodes`: number of different users for the simulation
- `num_seconds`: amount of time to run the simulation (in secs)

### Examples

```text
100 100
500 2000
```

The program upon execution will start the server, bootstrap the simulation, and collect the statistics.

## What is Working

- **User creation**: Multiple simulated users can participate on the platform.  
- **Post creation**: Users can create posts successfully.  
- **Commenting**: Users can comment on posts.  
- **Voting**: Upvotes and downvotes are correctly registered and affect post scores.  
- **Post ranking**: Posts are ranked according to votes and activity.  
- **Network interactions**: User actions are correctly simulated over the REST API.  
- **Digital signatures**: Users can verify post integrity using RSA public key signatures.  
- **Activity tracking**: The system collects and reports statistics such as the number of posts, comments, and votes over time.  
- **Scalability**: Supports a large number of users while maintaining correctness in post and comment propagation.
