FROM public.ecr.aws/aws-ec2/amazon-ec2-metadata-mock:v1.11.2 AS aemm
FROM public.ecr.aws/amazonlinux/amazonlinux:2
RUN amazon-linux-extras enable docker && \
    yum install -y jq containerd wget which && \
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
    chmod a+x /usr/local/bin/yq && \
    yum clean all

ENV IMDS_ENDPOINT=127.0.0.1:1338
COPY --from=aemm /ec2-metadata-mock /sbin/ec2-metadata-mock
RUN mkdir -p /etc/systemd/system && \
    mkdir -p /etc/eks/containerd
COPY ubuntu/runtime/ /etc/eks/
COPY shared/runtime/ /etc/eks/
COPY ubuntu/runtime/containerd-config.toml ubuntu/runtime/kubelet-containerd.service ubuntu/runtime/pull-sandbox-image.sh ubuntu/runtime/sandbox-image.service /etc/eks/containerd/
COPY ubuntu/runtime/kubelet-config.json /etc/kubernetes/kubelet/kubelet-config.json
COPY ubuntu/runtime/kubelet-kubeconfig /var/lib/kubelet/kubeconfig
COPY ubuntu/runtime/ecr-credential-provider-config.json /etc/eks/image-credential-provider/config.json
COPY test/entrypoint.sh /entrypoint.sh
COPY ubuntu/runtime/bin/* /usr/bin/
COPY shared/runtime/bin/* /usr/bin/
COPY test/mocks/ /sbin/
ENTRYPOINT ["/entrypoint.sh"]
