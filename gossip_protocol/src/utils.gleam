pub fn get_cube_root(number: Int, current_val: Int) -> Result(Int, Nil) {
  let remaining_val: Int = number - { current_val * current_val * current_val }
  case remaining_val == 0 {
    True -> Ok(current_val)
    False -> {
      case remaining_val > 0 {
        True -> get_cube_root(number, current_val + 1)
        False -> Error(Nil)
      }
    }
  }
}

pub fn algorithm_to_string(algorithm: Algorithm) -> String {
  case algorithm {
    Gossip -> "gossip"
    PushSum -> "push-sum"
  }
}

pub fn algorithm_to_type(algorithm: String) -> Algorithm {
  case algorithm {
    "gossip" -> Gossip
    "push-sum" -> PushSum
    _ -> Gossip
  }
}

pub fn topology_to_string(topology: Topology) -> String {
  case topology {
    Full -> "full"
    Line -> "line"
    ThreeD -> "3d"
    Imp3D -> "imp3d"
  }
}

pub fn topology_to_type(topology: String) -> Topology {
  case topology {
    "full" -> Full
    "line" -> Line
    "3d" -> ThreeD
    "imp3d" -> Imp3D
    _ -> Full
  }
}

pub type Algorithm {
  Gossip
  PushSum
}

pub type Topology {
  Full
  Line
  ThreeD
  Imp3D
}
