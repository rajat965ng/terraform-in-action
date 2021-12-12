package test

import (
	"bytes"
	"context"
	"fmt"
	"github.com/hashicorp/terraform-exec/tfexec"
	//"github.com/hashicorp/terraform-exec/tfinstall"
	"github.com/hashicorp/hc-install/releases"
    "github.com/hashicorp/hc-install/product"
    "github.com/hashicorp/go-version"
	"github.com/rs/xid"
	"io/ioutil"
	"net/http"
	"os"
	"testing"
)

func TestTerraformModule(t *testing.T) {
	tmpDir, err := ioutil.TempDir("", "tfinstall")
	if err != nil {
		t.Error(err)
	}
	defer os.RemoveAll(tmpDir)
	//latestVersion := tfinstall.LatestVersion(tmpDir, false)
	installer := &releases.ExactVersion{
    		Product: product.Terraform,
    		Version: version.Must(version.NewVersion("1.0.6")),
    	}
	execPath, err := installer.Install(context.Background())//tfinstall.Find(latestVersion)
	if err != nil {
		t.Error(err)
	}

	workingDir := "./testfixtures"
	tf, err := tfexec.NewTerraform(workingDir, execPath)
	if err != nil {
		t.Error(err)
	}

	ctx := context.Background()
	err = tf.Init(ctx, tfexec.Upgrade(true), tfexec.LockTimeout("60s"))
	if err != nil {
		t.Error(err)
	}
	defer tf.Destroy(ctx)
	bucketName := fmt.Sprintf("bucket_name=%s", xid.New().String())
	err = tf.Apply(ctx, tfexec.Var(bucketName))
	if err != nil {
		t.Error(err)
	}

	state, err := tf.Show(context.Background())
	if err != nil {
		t.Error(err)
	}

	endpoint := state.Values.Outputs["endpoint"].Value.(string)
	url := fmt.Sprintf("http://%s", endpoint)
	resp, err := http.Get(url)
	if err != nil {
		t.Error(err)
	}
	buf := new(bytes.Buffer)
	buf.ReadFrom(resp.Body)
	t.Logf("\n%s", buf.String())

	if resp.StatusCode != http.StatusOK {
		t.Errorf("status code did not return 200")
	}

}
