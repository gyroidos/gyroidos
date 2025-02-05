pipeline {
	agent any

	options {
		checkoutToSubdirectory('.manifests')
		copyArtifactPermission('/GyroidOS_Pipelines/**');
	}

	environment {
		YOCTO_VERSION = 'kirkstone'
		BUILDUSER = "${sh(script:'id -u', returnStdout: true).trim()}"
		KVM_GID = "${sh(script:'getent group kvm | cut -d: -f3', returnStdout: true).trim()}"
	}

	parameters {
		string(name: 'CI_LIB_VERSION', defaultValue: 'main', description: 'Version of the gyroidos_ci_common library to be used (e.g. main or pull/<pr_num>/merge)')
		choice(name: 'GYROID_ARCH', choices: ['x86', 'arm32', 'arm64'], description: 'GyroidOS Target Architecture')
		choice(name: 'GYROID_MACHINE', choices: ['genericx86-64', 'apalis-imx8', 'raspberrypi2', 'raspberrypi3-64', 'raspberrypi4-64', 'raspberrypi5', 'tqma8mpxl'], description: 'GyroidOS Target Machine (Must be compatible with GYROID_ARCH!)')
		string(name: 'PR_BRANCHES', defaultValue: '', description: 'Comma separated list of pull request branches (e.g. meta-trustx=PR-177,meta-trustx-nxp=PR-13,gyroidos_build=PR-97)')
		choice(name: 'BUILD_INSTALLER', choices: ['n', 'y'], description: 'Build the GyroidOS installer (x86 only)')
		choice(name: 'REBUILD_PREVIOUS', choices: ['n', 'y'], description: 'Rebuild selected, previous build instead of just reusing image from artifacts')
		buildSelector defaultSelector: specific('${BUILD_NUMBER}'), name: 'BUILDSELECTOR', description: 'Image to perform integration tests on. Changing the default value skips the image build.'
		choice(name: 'SYNC_MIRRORS', choices: ['n', 'y'], description: 'Sync source mirrors after successful build')
		booleanParam(name: 'SKIP_WS_CLEANUP', defaultValue: false, description: 'If true, workspace cleanup after build will be skipped')
	}


	stages {
		stage('Source checks + unit tests') {
			agent {
					dockerfile {
						dir '.manifests'
						additionalBuildArgs '--build-arg=BUILDUSER=$BUILDUSER'
						args '--entrypoint=\'\' --env NODE_NAME="${NODE_NAME}"'
						reuseNode true
					}
			}

			stages {
				stage ('Prepare workspace') {
					steps {
						echo "Running on node $NODE_NAME"

						library identifier: "gyroidos_ci_common@${CI_LIB_VERSION}", retriever: modernSCM(
    						[$class: 'GitSCMSource', remote: "https://github.com/gyroidos/gyroidos_ci_common"])

						stepInitWs(workspace: "${WORKSPACE}",
									manifest_path: "${WORKSPACE}/.manifests",
									manifest_name: "yocto-${GYROID_ARCH}-${GYROID_MACHINE}.xml",
									gyroid_arch: GYROID_ARCH,
									gyroid_machine: GYROID_MACHINE,
									selector: buildParameter('BUILDSELECTOR'),
									rebuild_previous: "${REBUILD_PREVIOUS}",
									buildtype: "dev",
									pr_branches: PR_BRANCHES)
					}
				}

				stage ('Source Tests') {
					when {
						expression {
							if (! fileExists("gyroidos/cml")) {
								echo "CML sources not available, skipping initial tests"
								return false
							} else {
								echo "CML sources available, performing initial tests"
								return true
							}
						}
					}

					parallel {
							stage ('Code Format & Style') {
								steps {
									echo "Entering format test stage, workspace: ${WORKSPACE}"
									stepFormatCheck(workspace: WORKSPACE,
									sourcedir: "${WORKSPACE}/gyroidos/cml")
								}
							}

							/*
							 Intentionally mark the static code analysis stage as skipped
							 We want to show that we are performing static code analysis, but not
							 as part of Jenkins's pipeline.
							*/
							stage('Static Code Analysis') {
								when { expression { return false }}

								steps {
									sh label: 'Perform static code analysis', script: '''
										echo "Static Code Analysis is performed using Semmle."
										echo "Please check GitHub's project for results from Semmle's analysis."
									'''
								}
							}

							stage ('Unit tests') {
								steps {
									script {
										echo "Running on node $NODE_NAME"
										stepUnitTests(workspace: WORKSPACE,
													  sourcedir: "${WORKSPACE}/gyroidos/cml")
									}
								}
							}
						}
					}
				}
			} // Source checks + unit tests


		stage ('Build + Test Images') {

			// Build images in parallel
			matrix {
				axes {
					axis {
						name 'BUILDTYPE'
						values 'dev', 'production', 'ccmode', 'schsm', 'asan'
					}
				}

				agent {
					dockerfile {
						dir ".manifests"
						additionalBuildArgs '--build-arg=BUILDUSER=$BUILDUSER'
						args '''--entrypoint=\'\' -v /yocto_mirror/:/yocto_mirror --env NODE_NAME="${NODE_NAME}"
							  -v /home/${NODE_JENKINS_USER}/.ssh/known_hosts:/home/builder/.ssh/ci_known_hosts'''
						reuseNode false
					}
				}

				stages {
					stage ('Build image') {
						steps {
							script {
								if ("y" == SYNC_MIRRORS) {
								    sh label: 'Prepare .ssh/config', script: '''
									echo "Preparing .ssh/config for mirror sync"

								    cat > /home/builder/.ssh/config << EOF 
UserKnownHostsFile /home/builder/.ssh/ci_known_hosts
EOF
									'''

									sshagent(credentials: ['MIRROR_ACCESS']){
										stepBuildImage(workspace: WORKSPACE,
											manifest_path: "${WORKSPACE}/.manifests",
											manifest_name: "yocto-${GYROID_ARCH}-${GYROID_MACHINE}.xml",
											mirror_base_path: "/yocto_mirror",
											yocto_version: YOCTO_VERSION,
											gyroid_arch: GYROID_ARCH,
											gyroid_machine: GYROID_MACHINE,
											buildtype: BUILDTYPE,
											build_coreos: true,
											selector: buildParameter('BUILDSELECTOR'),
											build_installer: BUILD_INSTALLER,
											sync_mirrors: SYNC_MIRRORS,
											rebuild_previous: REBUILD_PREVIOUS)
									}
								} else {
									echo "wont sync mirrors"

									stepBuildImage(workspace: WORKSPACE,
													manifest_path: "${WORKSPACE}/.manifests",
													manifest_name: "yocto-${GYROID_ARCH}-${GYROID_MACHINE}.xml",
													mirror_base_path: "/yocto_mirror",
													yocto_version: YOCTO_VERSION,
													gyroid_arch: GYROID_ARCH,
													gyroid_machine: GYROID_MACHINE,
													buildtype: BUILDTYPE,
													build_coreos: true,
													selector: buildParameter('BUILDSELECTOR'),
													build_installer: BUILD_INSTALLER,
													sync_mirrors: SYNC_MIRRORS,
													rebuild_previous: REBUILD_PREVIOUS)
								}
							}
						}
					}
				}
			} // matrix
		} // stage 'Build + Test Images'


		stage ('Integration Tests') {
			matrix {
				axes {
					axis {
						name 'BUILDTYPE'
						values 'dev', 'production', 'ccmode', 'asan'
					}
				}

				agent {
					dockerfile {
						dir ".manifests"
						additionalBuildArgs '--build-arg=BUILDUSER=$BUILDUSER'
						args '--entrypoint=\'\' --device=/dev/kvm --group-add=$KVM_GID -p 2222 -p 5901 --env NODE_NAME="${NODE_NAME}"'
						label 'worker'
					}
				}

				stages {
					stage ('Perform tests') {
						steps {
							stepIntegrationTest(workspace: "${WORKSPACE}",
								manifest_path: "${WORKSPACE}/.manifests",
								source_tarball: "sources-${GYROID_ARCH}-${GYROID_MACHINE}.tar",
								gyroid_machine: GYROID_MACHINE,
								buildtype: "${BUILDTYPE}",
								test_mode: "${"asan" == BUILDTYPE ? "dev" : BUILDTYPE}",
								selector: buildParameter('BUILDSELECTOR'),
								stage_name: STAGE_NAME,
								schsm_serial: "",
								schsm_pin: "")
						}
					} // stage 'Perform tests'
				} // stages
			} // matrix
		} // stage 'Integration Tests'

		stage ('Token Tests') {
			agent {
				node { label 'testing' }
			}

			steps {
				lock('schsm-test') {
					stepIntegrationTest(workspace: "${WORKSPACE}",
						manifest_path: "${WORKSPACE}/.manifests",
						source_tarball: "sources-${GYROID_ARCH}-${GYROID_MACHINE}.tar",
						gyroid_machine: GYROID_MACHINE,
						buildtype: "schsm",
						test_mode: "ccmode",
						selector: buildParameter('BUILDSELECTOR'),
						stage_name: STAGE_NAME,
						schsm_serial: "${env.PHYSHSM}",
						schsm_pin: "${env.PHYSHSM_PIN}")
				}
			}
		} // stage 'Token Tests'


		/*TODO deploy the development and production images on separate machines
		  and start demo applications inside them (e.g. a webserver)*/
		stage('Live Deployment') {
			parallel {
				stage('Development Image') {
					/*TODO;Skipped for now*/
					when {
						expression {
							/*If branch trustx master and comes from main repo?*/
							return false
						}
					}

					steps {
						sh 'echo pass'
					}
				}

				stage('Production Image') {
					/*TODO;Skipped for now*/
					when {
						expression {
							/*If branch trustx master and comes from main repo?*/
							return false
						}
					}
					steps {
						sh 'echo pass'
					}
				}
			}
		}


		stage('Documentation Generation') {
			/*TODO;Skipped for now*/
			when {
				expression {
					/*If branch trustx master and comes from main repo?*/
					return false
				}
			}

			steps {
				sh 'echo pass'
			}
		} // stage 'Documentation Generation'
	} // stages

    post {
        always {
			script {
				if (params.SKIP_WS_CLEANUP) {
					echo "Skipping workspace cleanup as requested"
	    	        cleanWs cleanWhenAborted: true, cleanWhenFailure: true, cleanWhenNotBuilt: true, cleanWhenUnstable: true, notFailBuild: true
				} else {
					echo "Cleaning workspace"
	    	        cleanWs cleanWhenAborted: true, cleanWhenFailure: true, cleanWhenNotBuilt: true, cleanWhenUnstable: true, notFailBuild: true
				}
			}
        }
    }   
} // pipeline
