/*
 * Copyright (c) 2019, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

import CelleryLogo from "../../img/celleryLogo.svg";
import Container from "@material-ui/core/Container";
import Link from "@material-ui/core/Link";
import React from "react";
import Typography from "@material-ui/core/Typography";
import {withStyles} from "@material-ui/core/styles";
import * as PropTypes from "prop-types";

const styles = (theme) => ({
    footerContent: {
        backgroundColor: "#e5eaea",
        color: "#57595d",
        height: 60,
        display: "flex",
        alignItems: "center"
    },
    footerLink: {
        textTransform: "uppercase",
        color: "#57595d",
        letterSpacing: 1,
        fontWeight: 500,
        textDecoration: "none"
    },
    title: {
        flexGrow: 1
    },
    copyRightInfo: {
        display: "flex"
    },
    celleryLogoFooter: {
        height: 20,
        verticalAlign: "middle"
    }
});

const Footer = (props) => {
    const {classes} = props;

    return (
        <footer>
            <div className={classes.footerContent}>
                <Container maxWidth="md" className={classes.copyRightInfo}>
                    <Typography variant="subheading2" color="inherit" className={classes.title}>
                        &copy; 2019
                        <Link href="https://wso2.com" target="_blank"
                            className={classes.footerLink}> WSO2</Link>
                    </Typography>
                    <Link href="https://wso2-cellery.github.io/" target="_blank" className={classes.footerLink}>
                        <img src={CelleryLogo} className={classes.celleryLogoFooter} alt="Cellery logo"/>
                    </Link>
                </Container>
            </div>
        </footer>
    );
};

Footer.propTypes = {
    classes: PropTypes.object.isRequired
};

export default withStyles(styles)(Footer);
