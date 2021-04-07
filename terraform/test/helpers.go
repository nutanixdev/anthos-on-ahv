package terratest

import (
	"crypto/tls"
	b64 "encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func print(msg string) {
	log.Print("************************")
	log.Printf("* %s", msg)
	log.Print("************************")
}

func assertEmptyPlan(t *testing.T, terraformOptions *terraform.Options) {
	plan := terraform.InitAndPlan(t, terraformOptions)
	// Plan: 0 to add, 0 to change, 0 to destroy.
	print("asserting empty plan")
	if strings.Contains(plan, "No changes. Infrastructure is up-to-date.") {
		print("plan was empty -> No changes. Infrastructure is up-to-date.")
		return
	}
	if strings.Contains(plan, "0 to add, 0 to change, 0 to destroy.") {
		print("plan was empty -> 0 to add, 0 to change, 0 to destroy.")
		return
	}
	print("plan NOT empty")
	t.Fatalf("[FAIL] plan was expected to be empty but was %s", plan)
}

func assertPlanResult(t *testing.T, terraformOptions *terraform.Options, additions, changes, destroys int) {
	if additions < 0 {
		t.Fatalf("[TEST ERROR] number of expected additions must be >= 0")
	}
	if changes < 0 {
		t.Fatalf("[TEST ERROR] number of expected additions must be >= 0")
	}
	if destroys < 0 {
		t.Fatalf("[TEST ERROR] number of expected additions must be >= 0")
	}
	if additions == 0 && changes == 0 && destroys == 0 {
		assertEmptyPlan(t, terraformOptions)
	} else {
		plan := terraform.InitAndPlan(t, terraformOptions)
		expectedPlanResult := fmt.Sprintf("%d to add, %d to change, %d to destroy.", additions, changes, destroys)
		print(fmt.Sprintf("expecting plan to be : %s", expectedPlanResult))
		print(plan)
		if !strings.Contains(plan, expectedPlanResult) {
			t.Fatalf("[FAIL] plan was to have result '%s' was %s", expectedPlanResult, plan)
		}
	}
}

func printPlan(t *testing.T, terraformOptions *terraform.Options) {
	plan := terraform.InitAndPlan(t, terraformOptions)
	print(plan)
}

func runCommandOnVM(t *testing.T, sshHost ssh.Host, command string) string {
	description := fmt.Sprintf("SSH to VM %s", sshHost.Hostname)
	maxRetries := 30
	timeBetweenRetries := 5 * time.Second
	var output string
	var err error
	retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		output, err = ssh.CheckSshCommandE(t, sshHost, command)
		if err != nil {
			return "", fmt.Errorf("[FAIL] Failed to run SSH command due to error: %s", err)
		}
		return "", nil
	})
	return output
}

func generateBasicHeader(t *testing.T, username, password *string) map[string]string {
	var nutanixUsername string
	var nutanixPassword string
	if username == nil {
		nutanixUsername = readEnvVar(t, "NUTANIX_USERNAME")
	} else {
		nutanixUsername = *username
	}
	if password == nil {
		nutanixPassword = readEnvVar(t, "NUTANIX_PASSWORD")
	} else {
		nutanixPassword = *password
	}
	authString := fmt.Sprintf("%s:%s", nutanixUsername, nutanixPassword)
	sEnc := b64.StdEncoding.EncodeToString([]byte(authString))
	return map[string]string{
		"Authorization": fmt.Sprintf("Basic %s", sEnc),
		"Content-Type":  "application/json",
	}
}

func generateTLSConfig() *tls.Config {
	return &tls.Config{
		InsecureSkipVerify: true,
	}
}

func toJSONObject(t *testing.T, jsonString string) map[string]interface{} {
	jsonMap := make(map[string]interface{})
	err := json.Unmarshal([]byte(jsonString), &jsonMap)
	if err != nil {
		t.Fatalf("failed to unmarshal JSON while deleting entity: %s", err)
	}
	return jsonMap
}

func assertBetween(t *testing.T, cVal, minVal, maxVal int, msg string) {
	assert.LessOrEqual(t, cVal, maxVal, fmt.Sprintf("%s: expected %d to be less than or equal to %d", msg, cVal, maxVal))
	assert.Greater(t, cVal, minVal, fmt.Sprintf("%s: expected %d to be greater than %d", msg, cVal, minVal))
}

func readEnvVar(t *testing.T, envKey string) string {
	val := getEnvVar(envKey, "")
	assert.NotEmptyf(t, val, "[FAIL] environment varialbe %s was not set", envKey)
	return val
}

func getEnvVar(key, fallback string) string {
	value := os.Getenv(key)
	if len(value) == 0 {
		return fallback
	}
	return value
}

func getEmptyTargets() []string {
	return make([]string, 0)
}

func generateRandomNumber() int {
	rand.Seed(time.Now().UnixNano())
	return rand.Intn(100000)
}

//PrintToJSON comment
func PrintToJSON(v interface{}, msg string) {
	pretty, _ := json.MarshalIndent(v, "", "  ")
	log.Print("\n", msg, string(pretty))
}

func checkLastBoot(t *testing.T, sshHost ssh.Host) string {
	command := fmt.Sprint("stat -c %z /proc/")
	return runCommandOnVM(t, sshHost, command)
}
