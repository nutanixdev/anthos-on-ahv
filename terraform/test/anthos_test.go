package terratest

import (
	"fmt"
	"regexp"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	DEFAULTAMOUNTOFWORKERVMS = 2
	DEFAULTAMOUNTOFMASTERVMS = 3
)

func getDefaultAnthosVariables(anthosClusterName string) map[string]interface{} {
	defaults := map[string]interface{}{
		"amount_of_anthos_worker_vms": DEFAULTAMOUNTOFWORKERVMS,
		"anthos_cluster_name":         anthosClusterName,
		"anthos_version":              "1.6.1",
	}
	return defaults
}

func getAnthosTerraformOptions(t *testing.T, vars map[string]interface{}, targets []string) *terraform.Options {
	return terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../",
		NoColor:      true,
		Vars:         vars,
		EnvVars: map[string]string{
			"TF_LOG":      "trace",
			"TF_LOG_PATH": "tf.log",
		},
		Targets: targets,
	})
}

func createAnthosCluster(t *testing.T, terraformOptions *terraform.Options, expectError bool) error {
	if expectError {
		_, err := terraform.InitAndApplyE(t, terraformOptions)
		return err
	}
	terraform.InitAndApply(t, terraformOptions)
	return nil
}

func TestTerraform_Anthos_CreateCluster(t *testing.T) {
	anthosClusterName := fmt.Sprintf("terratest-anthos-%d", generateRandomNumber())
	vars := getDefaultAnthosVariables(anthosClusterName)
	terraformOptions := getAnthosTerraformOptions(t, vars, getEmptyTargets())
	defer terraform.Destroy(t, terraformOptions)
	createAnthosCluster(t, terraformOptions, false)
	basicClusterTestHelper(t, terraformOptions, 0, 0, 0)
}

func TestTerraform_Anthos_CreateClusterMultipleWorkerNodes(t *testing.T) {
	anthosClusterName := fmt.Sprintf("terratest-anthos-%d", generateRandomNumber())
	vars := getDefaultAnthosVariables(anthosClusterName)
	vars["amount_of_anthos_worker_vms"] = 4
	terraformOptions := getAnthosTerraformOptions(t, vars, getEmptyTargets())
	defer terraform.Destroy(t, terraformOptions)
	createAnthosCluster(t, terraformOptions, false)
	basicClusterTestHelper(t, terraformOptions, 0, 0, 0)
}

func TestTerraform_Anthos_ClusterScaling(t *testing.T) {
	anthosClusterName := fmt.Sprintf("terratest-anthos-%d", generateRandomNumber())
	vars := getDefaultAnthosVariables(anthosClusterName)
	terraformOptions := getAnthosTerraformOptions(t, vars, getEmptyTargets())
	defer terraform.Destroy(t, terraformOptions)
	createAnthosCluster(t, terraformOptions, false)
	basicClusterTestHelper(t, terraformOptions, 0, 0, 0)
	k8sOptions := k8s.NewKubectlOptions("", getKubeconfigPath(terraformOptions, anthosClusterName), "kube-system")
	clusterScalingTestHelper(t, k8sOptions, terraformOptions, 4, DEFAULTAMOUNTOFMASTERVMS, 4, 0, 2)
	clusterScalingTestHelper(t, k8sOptions, terraformOptions, 1, DEFAULTAMOUNTOFMASTERVMS, 2, 0, 5)
}

func TestTerraform_Anthos_UpgradeCluster(t *testing.T) {
	anthosClusterName := fmt.Sprintf("terratest-anthos-%d", generateRandomNumber())
	vars := getDefaultAnthosVariables(anthosClusterName)
	vars["amount_of_anthos_worker_vms"] = 2
	terraformOptions := getAnthosTerraformOptions(t, vars, getEmptyTargets())
	defer terraform.Destroy(t, terraformOptions)
	createAnthosCluster(t, terraformOptions, false)
	basicClusterTestHelper(t, terraformOptions, 0, 0, 0)
	terraformOptions.Vars["anthos_version"] = "1.7.0"
	assertPlanResult(t, terraformOptions, 2, 0, 2)
	terraform.InitAndApply(t, terraformOptions)
	basicClusterTestHelper(t, terraformOptions, 0, 0, 0)
}

func clusterScalingTestHelper(t *testing.T, k8sOptions *k8s.KubectlOptions, terraformOptions *terraform.Options, amountOfWorkers, amountOfMasters, add, change, destroy int) {
	terraformOptions.Vars["amount_of_anthos_worker_vms"] = amountOfWorkers
	assertPlanResult(t, terraformOptions, add, change, destroy)
	terraform.InitAndApply(t, terraformOptions)
	checkAmountOfNodes(t, k8sOptions, terraformOptions.Vars["amount_of_anthos_worker_vms"].(int), amountOfMasters)
	hasCSIPods(t, k8sOptions)
}

func getPrivateKeyPath(clusterName string) string {
	return fmt.Sprintf("../anthos_%s", clusterName)
}

func getKubeconfigPath(terraformOptions *terraform.Options, clusterName string) string {
	return fmt.Sprintf("%s/%s-kubeconfig", terraformOptions.TerraformDir, clusterName)
}

func basicClusterTestHelper(t *testing.T, terraformOptions *terraform.Options, added, changed, deleted int) {
	assertPlanResult(t, terraformOptions, added, changed, deleted)
	amountOfWorkerNodes := terraformOptions.Vars["amount_of_anthos_worker_vms"].(int)
	clusterName := terraformOptions.Vars["anthos_cluster_name"].(string)
	expectedAnthosVersion := terraformOptions.Vars["anthos_version"].(string)
	k8sOptions := k8s.NewKubectlOptions("", getKubeconfigPath(terraformOptions, clusterName), "kube-system")
	checkAmountOfNodes(t, k8sOptions, amountOfWorkerNodes, DEFAULTAMOUNTOFMASTERVMS)
	hasCSIPods(t, k8sOptions)
	isExpectedAnthosVersion(t, k8sOptions, expectedAnthosVersion)
}

func checkAmountOfNodes(t *testing.T, k8sOptions *k8s.KubectlOptions, expectedAmountOfWorkerNodes int, amountOfMasters int) {
	currentNodes := k8s.GetNodes(t, k8sOptions)
	totalAmountOfNodes := expectedAmountOfWorkerNodes + amountOfMasters
	currentAmountOfNodes := len(currentNodes)
	assert.Equal(t, totalAmountOfNodes, currentAmountOfNodes, fmt.Sprintf("expected the amount of nodes to be %d but was %d", totalAmountOfNodes, currentAmountOfNodes))
}

func hasCSIPods(t *testing.T, k8sOptions *k8s.KubectlOptions) {
	csiProvisionerName := "csi-provisioner-ntnx-plugin"
	csiProvisionerExists := podExists(t, k8sOptions, csiProvisionerName)
	assert.True(t, csiProvisionerExists, fmt.Sprintf("csi pods containing name %s not found", csiProvisionerName))
	csiNodeName := "csi-node-ntnx-plugin"
	csiNodeExists := podExists(t, k8sOptions, csiNodeName)
	assert.True(t, csiNodeExists, fmt.Sprintf("csi pods containing name %s not found", csiNodeName))
}

func podExists(t *testing.T, k8sOptions *k8s.KubectlOptions, podName string) bool {
	listOption := metav1.ListOptions{}
	pods := k8s.ListPods(t, k8sOptions, listOption)

	found := false
	for _, p := range pods {
		found = strings.Contains(p.ObjectMeta.Name, podName)
		if found {
			break
		}
	}
	return found
}

func isExpectedAnthosVersion(t *testing.T, k8sOptions *k8s.KubectlOptions, expectedAnthosVersion string) {
	anthosVersionFullOutput, err := k8s.RunKubectlAndGetOutputE(t, k8sOptions, "get", "cluster", "--all-namespaces", "-o", "yaml")
	if err != nil {
		t.Fatalf("error occurred getting Anthos version: %s", err)
	}
	anthosVersionFullOutputList := strings.Split(anthosVersionFullOutput, "\n")
	anthosVersion := ""
	r, _ := regexp.Compile("^ *anthosBareMetalVersion:")
	for _, l := range anthosVersionFullOutputList {
		if r.Match([]byte(l)) {
			print(l)
			matchedLineList := strings.Split(l, ": ")
			anthosVersion = matchedLineList[len(matchedLineList)-1]
			break
		}
	}
	if anthosVersion == "" {
		t.Fatalf("unable occurred getting Anthos version via kubectl")
	}
	assert.Equalf(t, expectedAnthosVersion, anthosVersion, fmt.Sprintf("expected anthos cluster version to be %s but was %s", expectedAnthosVersion, anthosVersion))
}
