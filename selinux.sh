find vendor/ -exec stat -c "%n %C" {} \; > selinux_contexts.txt
