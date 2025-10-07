"""
The data below is obtained by running the `run analysis` scripts
"""

import matplotlib.pyplot as plt


def plot_combined():
    # Gossip
    plt.figure(figsize=(8, 5))
    plt.plot(
        [10, 50, 100, 300, 500, 1000, 1500, 2000, 3000],
        [
            0.005955934524536133,
            0.005305767059326172,
            0.009300947189331055,
            0.03335237503051758,
            0.08002138137817383,
            0.2738029956817627,
            0.6396474838256836,
            0.9760687351226807,
            2.195636034011841,
        ],
        marker="o",
        label="Full",
    )
    plt.plot(
        [10, 50, 100, 150, 200, 300, 400, 500, 1000],
        [
            0.004581451416015625,
            0.011728525161743164,
            0.018202781677246094,
            0.023275136947631836,
            0.11788702011108398,
            0.10658764839172363,
            0.31172776222229004,
            0.6527600288391113,
            1.311277151107788,
        ],
        marker="o",
        label="Line",
    )
    plt.plot(
        [8, 27, 64, 125, 216, 343, 512, 729, 1000, 8000, 27000, 64000, 125000],
        [
            0.004202842712402344,
            0.004460811614990234,
            0.006413936614990234,
            0.010851621627807617,
            0.0227968692779541,
            0.02379012107849121,
            0.053174495697021484,
            0.05864357948303223,
            0.08162856101989746,
            0.638333797454834,
            2.867417097091675,
            6.675585985183716,
            38.30363440513611,
        ],
        marker="o",
        label="3D Grid",
    )
    plt.plot(
        [8, 27, 64, 125, 216, 343, 512, 729, 1000, 8000, 27000, 64000, 125000],
        [
            0.005658626556396484,
            0.0048677921295166016,
            0.007768154144287109,
            0.011202335357666016,
            0.017565250396728516,
            0.02589249610900879,
            0.04881548881530762,
            0.06475186347961426,
            0.14658403396606445,
            0.9030308723449707,
            2.734679937362671,
            7.791430950164795,
            33.5526020526886,
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
        [10, 50, 100, 300, 500, 1000, 2000, 3000],
        [
            0.005171298980712891,
            0.0074253082275390625,
            0.013941049575805664,
            0.052103281021118164,
            0.10763216018676758,
            0.3489522933959961,
            1.2512767314910889,
            2.4849863052368164,
        ],
        marker="o",
        label="Full",
    )
    plt.plot(
        [10, 25, 50, 75, 100, 200],
        [
            0.00733184814453125,
            0.04499959945678711,
            0.28415918350219727,
            0.8615131378173828,
            2.059047222137451,
            14.951547384262085,
        ],
        marker="o",
        label="Line",
    )
    plt.plot(
        [125, 512, 1000, 3375, 8000],
        [
            0.03604316711425781,
            0.37023210525512695,
            0.9808235168457031,
            7.989028215408325,
            37.62832689285278,
        ],
        marker="o",
        label="3D Grid",
    )
    plt.plot(
        [125, 512, 1000, 3375, 8000, 15625, 27000],
        [
            0.028978824615478516,
            0.20749640464782715,
            0.4310770034790039,
            0.7738757133483887,
            2.7778449058532715,
            8.079915046691895,
            14.424173831939697,
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


def plot_combined_drop_node():
    # Gossip - drop_node
    plt.figure(figsize=(8, 5))
    plt.plot(
        [10, 50, 100, 300, 500, 1000, 1500, 2000, 3000],
        [
            0.004797220230102539,
            0.006671428680419922,
            0.009639739990234375,
            0.04434990882873535,
            0.08796191215515137,
            0.2953829765319824,
            0.6957592964172363,
            1.2874376773834229,
            2.732028007507324,
        ],
        marker="o",
        label="Full",
    )
    plt.plot(
        [8, 27, 64, 125, 216, 343, 512, 729, 1000, 8000, 27000, 64000, 125000],
        [
            0.004522800445556641,
            0.0051233768463134766,
            0.005992412567138672,
            0.009889602661132812,
            0.014169454574584961,
            0.015228748321533203,
            0.023041725158691406,
            0.04324674606323242,
            0.06926178932189941,
            0.4586145877838135,
            1.4730684757232666,
            4.735389471054077,
            27.672972440719604,
        ],
        marker="o",
        label="3D Grid",
    )
    plt.xscale("log")
    plt.yscale("log")
    plt.xlabel("Number of Nodes")
    plt.ylabel("Convergence Time (s)")
    plt.title("Gossip Protocol - drop_node (Full & 3D Only)")
    plt.grid(True, which="both", ls="--")
    plt.legend()
    plt.tight_layout()
    plt.savefig("gossip_drop_node.png")
    plt.close()

    # Push-Sum - drop_node
    plt.figure(figsize=(8, 5))
    plt.plot(
        [10, 50, 100, 300, 500, 1000, 2000, 3000],
        [
            0.005030393600463867,
            0.007773160934448242,
            0.014117240905761719,
            0.06003713607788086,
            0.1116185188293457,
            0.3664395809173584,
            1.431227684020996,
            3.4247829914093018,
        ],
        marker="s",
        label="Full",
    )
    plt.plot(
        [125, 512, 1000, 3375, 8000],
        [
            0.03658175468444824,
            0.327683687210083,
            0.8208818435668945,
            6.775849103927612,
            30.90833830833435,
        ],
        marker="s",
        label="3D Grid",
    )
    plt.xscale("log")
    plt.yscale("log")
    plt.xlabel("Number of Nodes")
    plt.ylabel("Convergence Time (s)")
    plt.title("Push-Sum Protocol - drop_node (Full & 3D Only)")
    plt.grid(True, which="both", ls="--")
    plt.legend()
    plt.tight_layout()
    plt.savefig("pushsum_drop_node.png")
    plt.close()


def main():
    plot_combined()
    plot_combined_drop_node()


if __name__ == "__main__":
    main()
