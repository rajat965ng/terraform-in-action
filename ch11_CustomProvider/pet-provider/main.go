package main

import (
	"github.com/hashicorp/terraform-plugin-sdk/v2/plugin"
	"github.com/rajat965ng/terraform-in-action/tree/master/ch11_CustomProvider/pet-provider/petstore"
)

func main() {
	plugin.Serve(&plugin.ServeOpts{
		ProviderFunc: petstore.Provider})
}
