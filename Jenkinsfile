pipeline {
	agent any

	options {
		checkoutToSubdirectory('.manifests')
		copyArtifactPermission('/GyroidOS_Pipelines/**');
	}

	environment {
		YOCTO_VERSION = 'scarthgap'
		BUILDUSER = "${sh(script:'id -u', returnStdout: true).trim()}"
	}


	parameters {
		string(name: 'CI_LIB_VERSION', defaultValue: 'main', description: 'Version of the gyroidos_ci_common library to be used (e.g. main or pull/<pr_num>/merge)')
		string(name: 'LABEL_BUILDER', defaultValue: 'worker', description: 'Builder preference')
		string(name: 'LABEL_TESTER', defaultValue: 'tester', description: 'Tester preference')
		choice(name: 'GYROID_ARCH', choices: ['x86', 'arm32', 'arm64', 'riscv'], description: 'GyroidOS Target Architecture')
		choice(name: 'GYROID_MACHINE', choices: ['genericx86-64', 'apalis-imx8', 'raspberrypi2', 'raspberrypi3-64', 'raspberrypi4-64', 'raspberrypi5', 'tqma8mpxl', 'tqmlx2160a', 'ls1088ardb-pb', 'beaglev-fire'], description: 'GyroidOS Target Machine (Must be compatible with GYROID_ARCH!)')
		string(name: 'PR_BRANCHES', defaultValue: '', description: 'Comma separated list of pull request branches (e.g. meta-gyroidos=PR-177,meta-gyroidos-nxp=PR-13,gyroidos_build=PR-97)')
		choice(name: 'BUILD_INSTALLER', choices: ['n', 'y'], description: 'Build the GyroidOS installer (x86 only)')
		choice(name: 'REBUILD_PREVIOUS', choices: ['n', 'y'], description: 'Rebuild selected, previous build instead of just reusing image from artifacts')
		buildSelector defaultSelector: specific('${BUILD_NUMBER}'), name: 'BUILDSELECTOR', description: 'Image to perform integration tests on. Changing the default value skips the image build.'
		choice(name: 'SYNC_MIRRORS', choices: ['n', 'y'], description: 'Sync source mirrors after successful build')
		booleanParam(name: 'SKIP_WS_CLEANUP', defaultValue: false, description: 'If true, workspace cleanup after build will be skipped')
		string(name: 'PKI_PATH', defaultValue: '', description: 'PKI path')
		password(name: 'PKI_PASSWORD', defaultValue: '', description: 'PKI password')
		booleanParam(name: 'SET_KEEP_FOREVER', defaultValue: false, description: 'Set "Keep this build forever"')
		string(name: 'SET_DISPLAY_NAME', defaultValue: "", description: 'Set display name')
	}


	stages {
		stage('Source checks + unit tests') {
			agent {
				node {
					label "${LABEL_BUILDER}"
				}
			}

			stages {
				stage('Prepare workspace') {
					steps {
						echo "Running on node $NODE_NAME"

						library identifier: "gyroidos_ci_common@${CI_LIB_VERSION}", retriever: modernSCM(
							[$class: 'GitSCMSource', remote: "https://github.com/gyroidos/gyroidos_ci_common"])

						script {
							if (params.SET_KEEP_FOREVER) {
								echo "Keeping this build forever"
								currentBuild.setKeepLog(true)
							} else {
								echo "Leaving currentBuild.keepLog as is: ${currentBuild.keepLog}"	
							}

							if ("" != params.SET_DISPLAY_NAME) {
								echo "Setting name to ${params.SET_DISPLAY_NAME}"
								currentBuild.displayName = params.SET_DISPLAY_NAME
							} else {
								echo "Leaving currentBuild.displayName as is: ${currentBuild.displayName}"	
							}

							def docker_image = docker.build("debian_jenkins_${BUILDUSER}_${KVM_GID}", "--build-arg=BUILDUSER=$BUILDUSER --build-arg=KVM_GID=${KVM_GID} ${WORKSPACE}/.manifests")
							docker_image.inside("--user ${BUILDUSER} --env NODE_NAME=${NODE_NAME}") {
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
					}
				}

				stage('Source Tests') {
					when {
						expression {
							if (!fileExists("gyroidos/cml")) {
								echo "CML sources not available, skipping initial tests"
								return false
							} else {
								echo "CML sources available, performing initial tests"
								return true
							}
						}
					}

					parallel {
						stage('Code Format & Style') {
							steps {
								script {
									def docker_image = docker.build("debian_jenkins_${BUILDUSER}_${KVM_GID}", "--build-arg=BUILDUSER=$BUILDUSER --build-arg=KVM_GID=${KVM_GID} ${WORKSPACE}/.manifests")
									docker_image.inside("--user ${BUILDUSER} --env NODE_NAME=${NODE_NAME}") {
										stepFormatCheck(workspace: WORKSPACE,
											sourcedir: "${WORKSPACE}/gyroidos/cml")
									}
								}
							}
						}

						/*
						 Intentionally mark the static code analysis stage as skipped
						 We want to show that we are performing static code analysis, but not
						 as part of Jenkins's pipeline.
						*/
						stage('Static Code Analysis') {
							when {
								expression {
									return false
								}
							}

							steps {
								echo "Running on node $NODE_NAME"

								sh label: 'Perform static code analysis', script: '''
								echo "Static Code Analysis is performed using Semmle."
								echo "Please check GitHub's project for results from Semmle's analysis."
								'''
							}
						}

						stage('Unit tests') {
							steps {
								echo "Running on node $NODE_NAME"

								script {
									def docker_image = docker.build("debian_jenkins_${BUILDUSER}_${KVM_GID}", "--build-arg=BUILDUSER=$BUILDUSER --build-arg=KVM_GID=${KVM_GID} ${WORKSPACE}/.manifests")
									docker_image.inside("--user ${BUILDUSER} --env NODE_NAME=${NODE_NAME}") {
										stepUnitTests(workspace: WORKSPACE,
											sourcedir: "${WORKSPACE}/gyroidos/cml")
									}
								}
							}
						}
					}
				}
			}
		} // Source checks + unit tests


		stage('Build + Test Images') {

			// Build images in parallel
			matrix {
				axes {
					axis {
						name 'BUILDTYPE'
						values 'dev', 'production', 'ccmode', 'schsm', 'bnse', 'asan'
					}
				}

				agent {
					node {
						label "${LABEL_BUILDER}"
					}
				}

				stages {
					stage('Build image') {
						steps {
							echo "Running on node $NODE_NAME"

							script {
								def docker_image = docker.build("debian_jenkins_${BUILDUSER}_${KVM_GID}", "--build-arg=BUILDUSER=$BUILDUSER --build-arg=KVM_GID=${KVM_GID} ${WORKSPACE}/.manifests")

								def run_args = '''--user ${BUILDUSER} -v /yocto_mirror/:/yocto_mirror --env NODE_NAME="${NODE_NAME}"
												-v /home/${NODE_JENKINS_USER}/.ssh/known_hosts:/home/builder/.ssh/ci_known_hosts
												--tmpfs /ext_tmpfs'''

								docker_image.inside(run_args) {
									def doBuild = {
										env.PKI_PASSWD = params.PKI_PASSWD

										sh label: 'Perform Yocto build', script: """
											if ! [ -z "${PKI_PATH}" ];then
												echo "Using PKI at ${PKI_PATH}"

												ls -al /yocto_mirror

												ln -s /yocto_mirror/gyroidos_release_pki "${WORKSPACE}/out-${BUILDTYPE}/test_certificates"

												ls -al "${WORKSPACE}/out-${BUILDTYPE}/test_certificates"

												if ! [ -z "\$PKI_PASSWD" ];then
													export KBUILD_SIGN_PIN="\$PKI_PASSWD"
													export GYROIDOS_TEST_PASSWD_PKI="\$PKI_PASSWD"
												fi
											else
												echo "No PKI specified, new one will be generated"
											fi

											cd "${WORKSPACE}"
											env

											echo "Building gyroidos-core"
											. gyroidos/build/yocto/init_ws_ids.sh "out-${BUILDTYPE}" "${GYROID_ARCH}" "${GYROID_MACHINE}"

											bitbake mc:guestos:gyroidos-core

											echo "Building gyroidos-cml"
											bitbake gyroidos-cml

											if [ "y" = "${BUILD_INSTALLER}" ];then
												echo "Building gyroidos-installer"
												bitbake multiconfig:installer:gyroidos-installer
											fi
										"""
									}

									if ("y" == SYNC_MIRRORS) {
										sh label: 'Prepare .ssh/config', script: '''
											echo "Preparing .ssh/config for mirror sync"
											echo "UserKnownHostsFile /home/builder/.ssh/ci_known_hosts" >> /home/builder/.ssh/config'''

										sshagent(credentials: ['MIRROR']) {
											sh label: 'sshtest', script: """
												echo "Test ssh agent"
												cat /home/builder/.ssh/ci_known_hosts
												cat /home/builder/.ssh/config
												ssh -v ${env.MIRRORHOST} "ls -al /yocto_mirror"
											"""
										}

										sshagent(credentials: ['MIRROR']) {
											stepBuildImage(workspace: WORKSPACE,
												manifest_path: "${WORKSPACE}/.manifests",
												manifest_name: "yocto-${GYROID_ARCH}-${GYROID_MACHINE}.xml",
												mirror_base_path: "/yocto_mirror",
												yocto_version: YOCTO_VERSION,
												gyroid_arch: GYROID_ARCH,
												gyroid_machine: GYROID_MACHINE,
												buildtype: BUILDTYPE,
												selector: buildParameter('BUILDSELECTOR'),
												sync_mirrors: SYNC_MIRRORS,
												rebuild_previous: REBUILD_PREVIOUS,
												buildSteps: doBuild
												)
										}
									} else {
										echo "won't sync mirrors"

										stepBuildImage(workspace: WORKSPACE,
											manifest_path: "${WORKSPACE}/.manifests",
											manifest_name: "yocto-${GYROID_ARCH}-${GYROID_MACHINE}.xml",
											mirror_base_path: "/yocto_mirror",
											yocto_version: YOCTO_VERSION,
											gyroid_arch: GYROID_ARCH,
											gyroid_machine: GYROID_MACHINE,
											buildtype: BUILDTYPE,
											selector: buildParameter('BUILDSELECTOR'),
											sync_mirrors: SYNC_MIRRORS,
											rebuild_previous: REBUILD_PREVIOUS,
											buildSteps: doBuild
										)
									}
								}
							}
						} // steps
					} //stage
				} // stages
			} // matrix
		} // stage 'Build + Test Images'


		stage('Integration Tests') {
			matrix {
				axes {
					axis {
						name 'BUILDTYPE'
						values 'dev', 'production', 'ccmode', 'asan'
					}
				}


				agent {
					node {
						label "${LABEL_TESTER}"
					}
				}

				stages {
					stage('Perform tests') {
						steps {
							echo "Running on node $NODE_NAME"

							script {
								def docker_image = docker.build("debian_jenkins_${BUILDUSER}_${KVM_GID}", "--build-arg=BUILDUSER=$BUILDUSER --build-arg=KVM_GID=${KVM_GID} ${WORKSPACE}/.manifests")
								def run_args = "--user ${BUILDUSER} --device=/dev/kvm -p 2222 -p 5901 --env NODE_NAME=${NODE_NAME} --env KVM_GID=${env.KVM_GID}"

								docker_image.inside(run_args) {
									stepIntegrationTest(workspace: "${WORKSPACE}",
										manifest_path: "${WORKSPACE}/.manifests",
										source_tarball: "sources-${GYROID_ARCH}-${GYROID_MACHINE}.tar",
										gyroid_machine: GYROID_MACHINE,
										buildtype: "${BUILDTYPE}",
										test_mode: "${"asan" == BUILDTYPE ? "dev" : BUILDTYPE}",
										selector: buildParameter('BUILDSELECTOR'),
										stage_name: STAGE_NAME,
										hsm_serial: "",
										hsm_vid: "",
										hsm_pid: "",
										hsm_pin: "")
								}
							}
						} // steps
					} // stage 'Perform tests'
				} // stages
			} // matrix
		} // stage 'Integration Tests'

		stage('Token Tests (SCHSM)') {
			agent {
				node {
					label "tokentest"
				}
			}

			steps {
				echo "Running on node $NODE_NAME"

				stepIntegrationTest(workspace: "${WORKSPACE}",
					manifest_path: "${WORKSPACE}/.manifests",
					source_tarball: "sources-${GYROID_ARCH}-${GYROID_MACHINE}.tar",
					gyroid_machine: GYROID_MACHINE,
					buildtype: "schsm",
					test_mode: "ccmode",
					selector: buildParameter('BUILDSELECTOR'),
					stage_name: STAGE_NAME,
					hsm_serial: "${env.SCHSM_SERIAL}",
					hsm_vid: "${env.SCHSM_VID}",
					hsm_pid: "${env.SCHSM_PID}",
					hsm_pin: "${env.PHYSHSM_PIN}")
			}
		} // stage 'Token Tests'

		stage('Token Tests (BNSE)') {
			agent {
				node {
					label "tokentest"
				}
			}

			steps {
				stepIntegrationTest(workspace: "${WORKSPACE}",
					manifest_path: "${WORKSPACE}/.manifests",
					source_tarball: "sources-${GYROID_ARCH}-${GYROID_MACHINE}.tar",
					gyroid_machine: GYROID_MACHINE,
					buildtype: "bnse",
					test_mode: "ccmode",
					selector: buildParameter('BUILDSELECTOR'),
					stage_name: STAGE_NAME,
					hsm_serial: "${env.BNSE_SERIAL}",
					hsm_vid: "${env.BNSE_VID}",
					hsm_pid: "${env.BNSE_PID}",
					hsm_pin: "${env.PHYSHSM_PIN}")
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
							/*If branch gyroidos master and comes from main repo?*/
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
							/*If branch gyroidos master and comes from main repo?*/
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
					/*If branch gyroidos master and comes from main repo?*/
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
// vim: ts=4
