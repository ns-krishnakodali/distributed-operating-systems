import matplotlib.pyplot as plt


def plot_combined():
    # Gossip
    plt.figure(figsize=(8, 5))
    plt.plot(
        [10, 50, 100, 300, 500, 1000, 1500],
        [0.004676, 0.006400, 0.014799, 0.087241, 0.310702, 3.110488, 10.179054],
        marker="o",
        label="Full",
    )
    plt.plot(
        [100, 500, 1000, 10000, 100000, 1000000],
        [0.005691, 0.007219, 0.010803, 0.074847, 0.728454, 16.731806],
        marker="o",
        label="Line",
    )
    plt.plot(
        [8, 27, 64, 125, 216, 343, 512, 729, 1000, 8000, 27000, 64000, 125000],
        [
            0.004770,
            0.004200,
            0.005185,
            0.005934,
            0.007751,
            0.012039,
            0.013517,
            0.018748,
            0.021252,
            0.148120,
            0.511690,
            1.274915,
            2.843772,
        ],
        marker="o",
        label="3D Grid",
    )
    plt.plot(
        [8, 27, 64, 125, 216, 343, 512, 729, 1000, 8000, 27000, 64000, 125000],
        [
            0.003930,
            0.004284,
            0.004957,
            0.006711,
            0.008563,
            0.011246,
            0.016663,
            0.023476,
            0.023836,
            0.204583,
            0.707022,
            1.795898,
            5.392281,
        ],
        marker="o",
        label="Imperfect 3D",
    )
    plt.xscale("log")
    plt.yscale("log")
    plt.xlabel("Number of Nodes")
    plt.ylabel("Convergence Time (s)")
    plt.title("Gossip Protocol - All Topologies")
    plt.grid(True, which="both", ls="--")
    plt.legend()
    plt.tight_layout()
    plt.savefig("gossip_all_topologies.png")
    plt.close()

    # Push-Sum
    plt.figure(figsize=(8, 5))
    plt.plot(
        [10, 50, 100, 300, 500, 1000, 1500],
        [0.004698, 0.009428, 0.021573, 0.117249, 0.382200, 3.043762, 10.538875],
        marker="o",
        label="Full",
    )
    plt.plot(
        [10, 25, 50, 75, 100],
        [0.007972, 0.031588, 0.177606, 54.270844, 54.098204],
        marker="o",
        label="Line",
    )
    plt.plot(
        [8, 27, 64, 125],
        [0.004849, 0.006848, 17.031732, 30.073029],
        marker="o",
        label="3D Grid",
    )
    plt.plot(
        [8, 64, 125, 512, 1000, 8000, 27000, 64000, 91125],
        [
            0.004515,
            0.012481,
            0.026886,
            0.144928,
            0.181980,
            2.001249,
            8.598558,
            26.565327,
            50.625811,
        ],
        marker="o",
        label="Imperfect 3D",
    )

    plt.xscale("log")
    plt.yscale("log")
    plt.xlabel("Number of Nodes")
    plt.ylabel("Convergence Time (s)")
    plt.title("Push-Sum Protocol - All Topologies")
    plt.grid(True, which="both", ls="--")
    plt.legend()
    plt.tight_layout()
    plt.savefig("pushsum_all_topologies.png")
    plt.close()


def main():
    plot_combined()


if __name__ == "__main__":
    main()
