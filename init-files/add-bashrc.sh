#
# BEGIN: Generated by vagrant provisioning script
#
echo ""
echo "For first time initialization (i.e. just after provisioning), "
echo "remember to run helm-init.sh AFTER the cluster is ready; e.g."
echo ""
echo "  ./init.sh"
echo ""
echo "Current node status is:"
echo
kubectl get nodes -o wide
echo ""
echo "Check node status before starting: nodes"
echo
#
# END:   Generated by vagrant provisioning script
#
function nodes() {
    kubectl get nodes -o wide
}